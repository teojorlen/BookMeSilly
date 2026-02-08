#!/usr/bin/env python3
"""
Simple converter from cppcheck XML output to SARIF v2.1.0
Usage: convert_cppcheck_xml_to_sarif.py <cppcheck-xml-file> <output-sarif-file>
"""
import sys
import xml.etree.ElementTree as ET
import json
import os

def severity_to_level(severity):
    """Map cppcheck severity levels to SARIF levels.
    
    Args:
        severity: The severity string from cppcheck ('error', 'warning', 'style', etc.)
        
    Returns:
        A SARIF level string ('error', 'warning', or 'note')
    """
    if severity is None:
        return "note"
    severity = severity.lower()
    if severity in ("error", "critical"):
        return "error"
    if severity in ("warning", "style"):
        return "warning"
    return "note"


def main():
    """Convert cppcheck XML output to SARIF v2.1.0 format.
    
    This function reads a cppcheck XML report and converts it to the SARIF
    v2.1.0 JSON format for integration with code analysis platforms.
    """
    if len(sys.argv) < 3:
        usage_msg = f"Usage: {sys.argv[0]} <cppcheck-xml-file> <output-sarif-file>"
        print(usage_msg, file=sys.stderr)
        sys.exit(2)
    xml_file = sys.argv[1]
    out_file = sys.argv[2]

    if not os.path.exists(xml_file):
        error_msg = f"Input file not found: {xml_file}"
        print(error_msg, file=sys.stderr)
        sys.exit(2)

    tree = ET.parse(xml_file)
    root = tree.getroot()

    # Build rules (unique from messages)
    rule_index = {}
    rules = []
    results = []

    for error in root.findall('errors/error'):
        _process_error(error, rule_index, rules, results)

    _write_sarif_report(out_file, rules, results)


def _process_error(error, rule_index, rules, results):
    """Process a single cppcheck error and update rules/results.
    
    Args:
        error: The error element from cppcheck XML
        rule_index: Dictionary tracking which rules have been added
        rules: List of SARIF rule objects
        results: List of SARIF result objects
    """
    msg = error.get('msg') or ''
    verbose = error.get('verbose') or ''
    severity = error.get('severity')
    cwe = error.get('cwe')
    error_id = error.get('id') or msg

    # Create rule if not exists
    if error_id not in rule_index:
        rule_index[error_id] = len(rules)
        rule = _build_rule(error_id, msg, verbose, severity, cwe)
        rules.append(rule)

    # Add error locations as results
    for loc in error.findall('location'):
        result = _build_result(loc, msg, error_id, severity)
        results.append(result)


def _build_rule(error_id, msg, verbose, severity, cwe):
    """Build a SARIF rule object from cppcheck error data."""
    rule = {
        'id': error_id,
        'shortDescription': {'text': msg},
        'fullDescription': {'text': verbose or msg},
        'defaultConfiguration': {'level': severity_to_level(severity)}
    }
    if cwe:
        rule['guid'] = cwe
    return rule


def _build_result(location_elem, msg, error_id, severity):
    """Build a SARIF result object from cppcheck location data."""
    file_path = location_elem.get('file')
    line_str = location_elem.get('line')
    start_line = int(line_str) if line_str and line_str.isdigit() else 1

    return {
        'message': {'text': msg},
        'ruleId': error_id,
        'level': severity_to_level(severity),
        'locations': [{
            'physicalLocation': {
                'artifactLocation': {'uri': file_path},
                'region': {'startLine': start_line}
            }
        }]
    }


def _write_sarif_report(out_file, rules, results):
    """Write the SARIF report to a file."""
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
