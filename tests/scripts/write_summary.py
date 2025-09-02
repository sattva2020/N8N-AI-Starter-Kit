import sys
from xml.etree import ElementTree as ET


def main(junit_xml: str, out_md: str) -> None:
    tree = ET.parse(junit_xml)
    root = tree.getroot()
    tests = int(root.attrib.get("tests", 0))
    failures = int(root.attrib.get("failures", 0))
    errors = int(root.attrib.get("errors", 0))
    skipped = int(root.attrib.get("skipped", 0))

    with open(out_md, "w", encoding="utf-8") as f:
        f.write("# Test Summary\n\n")
        f.write(f"- Tests: {tests}\n")
        f.write(f"- Failures: {failures}\n")
        f.write(f"- Errors: {errors}\n")
        f.write(f"- Skipped: {skipped}\n")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: write_summary.py <junit.xml> <out.md>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])
