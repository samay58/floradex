#!/usr/bin/env swift
// Usage:
//   swift examples/provider_quick_check.swift
// Description:
//   Prints which providers would be enabled based on environment variables
//   or a Secrets.xcconfig-provided build setting. Safe to run locally.
// Notes:
//   For the app, prefer setting keys via `Secrets.xcconfig`.

import Foundation

let env = ProcessInfo.processInfo.environment

let openAI = (env["OPENAI_API_KEY"]?.isEmpty == false)
let plantNet = (env["PLANTNET_API_KEY"]?.isEmpty == false)
let trefle = (env["TREFLE_API_KEY"]?.isEmpty == false)
let perenual = (env["PERENUAL_API_KEY"]?.isEmpty == false)

print("Provider quick check:\n")
print("- OpenAI GPT-4o: \(openAI ? "available" : "missing key")")
print("- PlantNet:      \(plantNet ? "available" : "missing key")")
print("- Trefle:        \(trefle ? "available" : "missing key")")
print("- Perenual:      \(perenual ? "available" : "missing key")")

if !openAI && plantNet {
    print("\nTip: OpenAI key missing; PlantNet will still work.")
} else if openAI && !plantNet {
    print("\nTip: PlantNet key missing; OpenAI will still work.")
} else if !openAI && !plantNet {
    print("\nOffline mode only: add keys to enable remote providers.")
}

