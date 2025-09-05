#!/usr/bin/env swift
// Usage:
//   swift examples/preview_services.swift
// Description:
//   Lists networking service files and any enum cases found for `*Endpoint`.
//   Helps you quickly see available API calls without opening Xcode.
// Notes:
//   Purely static scan; does not run network calls.

import Foundation

let fm = FileManager.default
let networkingPath = "plantlife/Networking"

guard let files = try? fm.contentsOfDirectory(atPath: networkingPath).sorted() else {
    print("Could not read \(networkingPath)")
    exit(1)
}

print("Scanning \(networkingPath)\n")
for file in files where file.hasSuffix(".swift") {
    let path = networkingPath + "/" + file
    guard let data = fm.contents(atPath: path), let text = String(data: data, encoding: .utf8) else { continue }
    var endpointName: String? = nil
    var cases: [String] = []
    for line in text.split(separator: "\n") {
        let s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("enum ") && s.contains("Endpoint") {
            endpointName = String(s)
        } else if s.hasPrefix("case ") {
            cases.append(String(s))
        }
    }
    if let endpointName = endpointName {
        print("\(file):")
        print("  \(endpointName)")
        if cases.isEmpty {
            print("  (no cases found)")
        } else {
            for c in cases { print("  - \(c)") }
        }
        print("")
    }
}

