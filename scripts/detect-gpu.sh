#!/bin/bash
# =============================================================================
# GPU DETECTION AND CONFIGURATION SCRIPT
# =============================================================================
# Automatically detects available GPU hardware and configures optimal settings
# Supports NVIDIA CUDA and AMD ROCm

set -euo pipefail

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

# GPU detection variables
GPU_TYPE=""
GPU_COUNT=0
GPU_MEMORY=""
GPU_DRIVER_VERSION=""
DOCKER_GPU_SUPPORT=false
RECOMMENDED_PROFILE=""

print_banner() {
    echo
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                          GPU DETECTION & SETUP${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${GREEN}  Detecting GPU hardware and configuring optimal settings${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo
}

# Function to detect NVIDIA GPUs
detect_nvidia_gpu() {
    print_info "Checking for NVIDIA GPU..."

    if command -v nvidia-smi >/dev/null 2>&1; then
        local nvidia_output
        nvidia_output=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null || echo "")

        if [[ -n "$nvidia_output" ]]; then
            GPU_TYPE="nvidia"
            GPU_COUNT=$(echo "$nvidia_output" | wc -l)

            # Get GPU details from first GPU
            local first_gpu
            first_gpu=$(echo "$nvidia_output" | head -n 1)

            local gpu_name
            gpu_name=$(echo "$first_gpu" | cut -d',' -f1 | xargs)

            GPU_MEMORY=$(echo "$first_gpu" | cut -d',' -f2 | xargs)
            GPU_DRIVER_VERSION=$(echo "$first_gpu" | cut -d',' -f3 | xargs)

            print_success "NVIDIA GPU detected: $gpu_name"
            print_info "GPU Count: $GPU_COUNT"
            print_info "GPU Memory: ${GPU_MEMORY}MB"
            print_info "Driver Version: $GPU_DRIVER_VERSION"

            # Check for multiple GPUs
            if [[ $GPU_COUNT -gt 1 ]]; then
                print_info "Multiple GPUs detected:"
                echo "$nvidia_output" | while IFS=',' read -r name memory driver; do
                    echo "  - $(echo "$name" | xargs): $(echo "$memory" | xargs)MB"
                done
            fi

            return 0
        fi
    fi

    return 1
}

# Function to detect AMD GPUs
detect_amd_gpu() {
    print_info "Checking for AMD GPU..."

    if command -v rocm-smi >/dev/null 2>&1; then
        local amd_output
        amd_output=$(rocm-smi --showproductname --showmeminfo vram --csv 2>/dev/null || echo "")

        if [[ -n "$amd_output" && "$amd_output" != *"No AMD GPUs found"* ]]; then
            GPU_TYPE="amd"
            GPU_COUNT=$(echo "$amd_output" | grep -c "GPU" || echo "1")

            # Extract memory info (simplified)
            GPU_MEMORY=$(echo "$amd_output" | grep -i "memory" | head -n 1 | grep -oE '[0-9]+' | head -n 1 || echo "Unknown")

            print_success "AMD GPU detected"
            print_info "GPU Count: $GPU_COUNT"
            print_info "GPU Memory: ${GPU_MEMORY}MB (estimated)"

            return 0
        fi
    fi

    # Alternative detection for AMD GPUs
    if lspci | grep -i "amd.*vga\|amd.*display\|radeon" >/dev/null 2>&1; then
        GPU_TYPE="amd"
        GPU_COUNT=1
        GPU_MEMORY="Unknown"

        print_warning "AMD GPU detected via lspci, but ROCm tools not available"
        print_info "Install ROCm for better GPU support: https://rocmdocs.amd.com/"

        return 0
    fi

    return 1
}

# Function to check Docker GPU support
check_docker_gpu_support() {
    print_info "Checking Docker GPU support..."

    case "$GPU_TYPE" in
        "nvidia")
            # Check for NVIDIA Container Toolkit
            if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1; then
                DOCKER_GPU_SUPPORT=true
                print_success "NVIDIA Docker GPU support is working"
            else
                print_warning "NVIDIA Docker GPU support not available"
                print_info "Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
            fi
            ;;
        "amd")
            # Check for ROCm Docker support
            if docker run --rm --device=/dev/kfd --device=/dev/dri rocm/rocm-terminal:latest rocm-smi >/dev/null 2>&1; then
                DOCKER_GPU_SUPPORT=true
                print_success "AMD ROCm Docker support is working"
            else
                print_warning "AMD ROCm Docker support not available"
                print_info "Install ROCm Docker support: https://rocmdocs.amd.com/"
            fi
            ;;
        *)
            print_warning "No GPU detected or unsupported GPU type"
            ;;
    esac
}

# Function to determine optimal configuration
determine_optimal_config() {
    print_info "Determining optimal configuration..."

    if [[ "$GPU_TYPE" == "nvidia" && "$DOCKER_GPU_SUPPORT" == "true" ]]; then
        # Memory-based recommendations
        local memory_gb
        memory_gb=$((GPU_MEMORY / 1024))

        if [[ $memory_gb -ge 24 ]]; then
            RECOMMENDED_PROFILE="gpu,rstar-gpu,developer-gpu,monitoring-gpu"
            print_success "High-end GPU detected (${memory_gb}GB) - Recommended profile: Full GPU stack"
        elif [[ $memory_gb -ge 12 ]]; then
            RECOMMENDED_PROFILE="gpu,rstar-gpu"
            print_success "Mid-range GPU detected (${memory_gb}GB) - Recommended profile: Core GPU services"
        elif [[ $memory_gb -ge 8 ]]; then
            RECOMMENDED_PROFILE="gpu"
            print_success "Entry-level GPU detected (${memory_gb}GB) - Recommended profile: Basic GPU services"
        else
            RECOMMENDED_PROFILE="default,developer"
            print_warning "Low VRAM detected (${memory_gb}GB) - Recommended profile: CPU fallback"
        fi
    elif [[ "$GPU_TYPE" == "amd" && "$DOCKER_GPU_SUPPORT" == "true" ]]; then
        # Memory-based recommendations for AMD GPUs (similar to NVIDIA)
        if [[ -n "$GPU_MEMORY" && "$GPU_MEMORY" != "Unknown" ]]; then
            local memory_gb
            memory_gb=$((GPU_MEMORY / 1024))

            if [[ $memory_gb -ge 16 ]]; then
                RECOMMENDED_PROFILE="gpu,developer-gpu"
                print_success "High-end AMD GPU detected (${memory_gb}GB) - Recommended profile: GPU + Development"
            elif [[ $memory_gb -ge 8 ]]; then
                RECOMMENDED_PROFILE="gpu"
                print_success "AMD GPU detected (${memory_gb}GB) - Recommended profile: Basic GPU services"
            else
                RECOMMENDED_PROFILE="default,developer"
                print_warning "Low VRAM AMD GPU detected (${memory_gb}GB) - Recommended profile: CPU fallback"
            fi
        else
            RECOMMENDED_PROFILE="gpu"
            print_success "AMD GPU with Docker support - Recommended profile: Basic GPU services"
        fi
    else
        RECOMMENDED_PROFILE="default,developer"
        print_info "No GPU support or GPU not detected - Recommended profile: CPU-only"
    fi
}

# Function to generate GPU configuration
generate_gpu_config() {
    print_info "Generating GPU configuration..."

    local gpu_config_file="$PROJECT_ROOT/config/gpu.env"
    mkdir -p "$(dirname "$gpu_config_file")"

    cat > "$gpu_config_file" << EOF
# =============================================================================
# GPU CONFIGURATION - AUTO-GENERATED
# =============================================================================
# Generated on: $(date)
# GPU Type: $GPU_TYPE
# GPU Count: $GPU_COUNT
# GPU Memory: ${GPU_MEMORY}MB
# Docker GPU Support: $DOCKER_GPU_SUPPORT

# GPU Hardware Information
GPU_TYPE=$GPU_TYPE
GPU_COUNT=$GPU_COUNT
GPU_MEMORY_MB=$GPU_MEMORY
GPU_DRIVER_VERSION=$GPU_DRIVER_VERSION
DOCKER_GPU_SUPPORT=$DOCKER_GPU_SUPPORT

# Recommended Docker Compose Profiles
RECOMMENDED_GPU_PROFILES=$RECOMMENDED_PROFILE

EOF

    if [[ "$GPU_TYPE" == "nvidia" ]]; then
        cat >> "$gpu_config_file" << EOF
# NVIDIA-specific configuration
CUDA_VISIBLE_DEVICES=all
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,utility

# NVIDIA Memory Management
GPU_MEMORY_FRACTION=0.8
PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256

# NVIDIA Optimization Settings
CUBLAS_WORKSPACE_CONFIG=:4096:8
CUDNN_DETERMINISTIC=1

EOF
    elif [[ "$GPU_TYPE" == "amd" ]]; then
        cat >> "$gpu_config_file" << EOF
# AMD ROCm-specific configuration
ROCR_VISIBLE_DEVICES=all
HIP_VISIBLE_DEVICES=all

# AMD Memory Management
GPU_MEMORY_FRACTION=0.8

EOF
    fi

    print_success "GPU configuration saved to: $gpu_config_file"
}

# Function to update main environment file
update_main_env() {
    print_info "Updating main environment file..."

    if [[ -f "$ENV_FILE" ]]; then
        # Remove old GPU settings if they exist
        sed -i '/^# GPU Configuration/,/^$/d' "$ENV_FILE" 2>/dev/null || true
        sed -i '/^GPU_TYPE=/d' "$ENV_FILE" 2>/dev/null || true
        sed -i '/^RECOMMENDED_GPU_PROFILES=/d' "$ENV_FILE" 2>/dev/null || true

        # Add new GPU settings
        cat >> "$ENV_FILE" << EOF

# GPU Configuration (auto-detected)
GPU_TYPE=$GPU_TYPE
RECOMMENDED_GPU_PROFILES=$RECOMMENDED_PROFILE

EOF

        print_success "Main environment file updated"
    else
        print_warning "Main environment file not found, skipping update"
    fi
}

# Function to run GPU benchmark
run_gpu_benchmark() {
    if [[ "$GPU_TYPE" != "nvidia" || "$DOCKER_GPU_SUPPORT" != "true" ]]; then
        print_info "Skipping benchmark (requires NVIDIA GPU with Docker support)"
        return 0
    fi

    print_info "Running GPU benchmark..."

    local benchmark_result
    benchmark_result=$(docker run --rm --gpus all \
        nvidia/cuda:11.0-runtime-ubuntu20.04 \
        bash -c 'nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits' 2>/dev/null || echo "Benchmark failed")

    if [[ "$benchmark_result" != "Benchmark failed" ]]; then
        print_success "GPU benchmark completed"
        echo "Current GPU status: $benchmark_result"
    else
        print_warning "GPU benchmark failed"
    fi
}

# Function to show GPU status summary
show_gpu_summary() {
    echo
    print_header "GPU Detection Summary"
    echo "======================================================================"

    if [[ -n "$GPU_TYPE" ]]; then
        echo "GPU Type:              $GPU_TYPE"
        echo "GPU Count:             $GPU_COUNT"
        echo "GPU Memory:            ${GPU_MEMORY}MB"
        echo "Driver Version:        $GPU_DRIVER_VERSION"
        echo "Docker GPU Support:    $DOCKER_GPU_SUPPORT"
        echo "Recommended Profiles:  $RECOMMENDED_PROFILE"
    else
        echo "No GPU detected or GPU not supported"
        echo "Recommended Profiles:  default,developer"
    fi

    echo "======================================================================"

    if [[ "$DOCKER_GPU_SUPPORT" == "true" ]]; then
        echo
        print_success "GPU acceleration is ready!"
        echo "To start with GPU acceleration:"
        echo "  ./start.sh --profile $RECOMMENDED_PROFILE"
        echo
        echo "To start specific GPU services:"
        echo "  ./start.sh --profile gpu                    # Basic GPU services"
        echo "  ./start.sh --profile rstar-gpu              # rStar2-Agent with GPU"
        echo "  ./start.sh --profile developer-gpu          # Development tools with GPU"
        echo "  ./start.sh --profile monitoring-gpu         # GPU monitoring"
    else
        echo
        print_warning "GPU acceleration not available"
        echo "Fallback to CPU-only services:"
        echo "  ./start.sh --profile default,developer"

        if [[ "$GPU_TYPE" == "nvidia" ]]; then
            echo
            echo "To enable NVIDIA GPU support:"
            echo "  1. Install NVIDIA Container Toolkit"
            echo "  2. Restart Docker daemon"
            echo "  3. Run this script again"
        elif [[ "$GPU_TYPE" == "amd" ]]; then
            echo
            echo "To enable AMD GPU support:"
            echo "  1. Install ROCm and ROCm Docker support"
            echo "  2. Restart Docker daemon"
            echo "  3. Run this script again"
        fi
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --detect-only       Only detect GPU, don't update configuration
    --benchmark         Run GPU benchmark after detection
    --no-docker-check   Skip Docker GPU support check
    --force-update      Force update configuration even if no GPU detected
    --help              Show this help message

EXAMPLES:
    $0                  # Full GPU detection and configuration
    $0 --detect-only    # Just detect and show GPU info
    $0 --benchmark      # Detect GPU and run benchmark

EOF
}

# Main function
main() {
    local detect_only=false
    local run_benchmark=false
    local check_docker=true
    local force_update=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --detect-only)
                detect_only=true
                shift
                ;;
            --benchmark)
                run_benchmark=true
                shift
                ;;
            --no-docker-check)
                check_docker=false
                shift
                ;;
            --force-update)
                force_update=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_banner

    # Detect GPUs
    if detect_nvidia_gpu; then
        print_success "NVIDIA GPU detection completed"
    elif detect_amd_gpu; then
        print_success "AMD GPU detection completed"
    else
        print_info "No GPU detected"
    fi

    # Check Docker GPU support
    if [[ "$check_docker" == "true" ]]; then
        check_docker_gpu_support
    fi

    # Determine optimal configuration
    determine_optimal_config

    # Run benchmark if requested
    if [[ "$run_benchmark" == "true" ]]; then
        run_gpu_benchmark
    fi

    # Update configuration files
    if [[ "$detect_only" == "false" ]]; then
        if [[ -n "$GPU_TYPE" || "$force_update" == "true" ]]; then
            generate_gpu_config
            update_main_env
        else
            print_info "No GPU detected, skipping configuration update"
        fi
    fi

    # Show summary
    show_gpu_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
