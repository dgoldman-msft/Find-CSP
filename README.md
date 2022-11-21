# Find-CSP
Find available configuration service providers

Connects to the Microsoft Docs and retrieve the list of currently documented CSP's

## Getting started

Copy this script down and save it to a local directory and run the following command: . .\Find-CSP.ps1

## Examples

- EXAMPLE 1: Find-CSP -CSP policy-csp-abovelock

    Retrieve the policy-csp-abovelock policy

- EXAMPLE 2: Find-CSP -CSP windows <ctrl + space>

    This will use dynamic tab completion and search all available csp's that contain the word 'windows'

NOTE: Each time you run this script it will connect to Microsoft docs and search for all available documented CSP's. This file will be stored as "$env:Temp\policiesFound.json". If this file is broken Dynamic Tab Completion will not work.
