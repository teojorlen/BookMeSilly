#!/usr/bin/env python3
"""
Simple converter from cppcheck XML output to SARIF v2.1.0
Usage: convert_cppcheck_xml_to_sarif.py <cppcheck-xml-file> <output-sarif-file>
"""
import sys
import xml.etree.ElementTree as ET
import json
import os

def severity_to_level(s):
    # Map cppcheck severity levels to SARIF levels
    if s is None:
        return "note"
    s = s.lower()
    if s in ("error", "critical"):
        return "error"
    if s in ("warning", "style"):
        return "warning"
    return "note"


def main():
    if len(sys.argv) < 3:
        print("Usage: {} <cppcheck-xml-file> <output-sarif-file>".format(sys.argv[0]), file=sys.stderr)
        sys.exit(2)
    xml_file = sys.argv[1]
    out_file = sys.argv[2]

    if not os.path.exists(xml_file):
        print("Input file not found: {}".format(xml_file), file=sys.stderr)
        sys.exit(2)

    tree = ET.parse(xml_file)
    root = tree.getroot()

    runs = []

    # Build rules (unique from messages)
    rule_index = {}
    rules = []
    results = []

    for error in root.findall('errors/error'):
        msg = error.get('msg') or ''
        verbose = error.get('verbose') or ''
        severity = error.get('severity')
        cwe = error.get('cwe')
        id_ = error.get('id') or msg

        # Create rule if not exists
        if id_ not in rule_index:
            rule_index[id_] = len(rules)
            rule = {
                'id': id_,
                'shortDescription': {'text': msg},
                'fullDescription': {'text': verbose or msg},
                'defaultConfiguration': {'level': severity_to_level(severity)}
            }
            if cwe:
                rule['guid'] = cwe
            rules.append(rule)

        # locations
        for loc in error.findall('location'):
            file_path = loc.get('file')
            line = loc.get('line')
            region = {
                'startLine': int(line) if line and line.isdigit() else 1
            }
            physical = {
                'artifactLocation': {'uri': file_path}
            }
            region_entry = {
                'message': {'text': msg},
                'ruleId': id_,
                'level': severity_to_level(severity),
                'locations': [{'physicalLocation': {**physical, 'region': region}}]
            }
            results.append(region_entry)

    sarif = {
        "$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json",
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "cppcheck",
                        "informationUri": "http://cppcheck.sourceforge.net/",
                        "rules": rules
                    }
                },
                "results": results
            }
        ]
    }

    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(sarif, f, indent=2)

if __name__ == '__main__':
    main()
