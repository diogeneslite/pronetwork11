@echo off
:: ============================================================================
:: ProNetwork11 - Windows 11 Network Operations & Diagnostics Toolkit
:: Author: diogeneslite (https://github.com/diogeneslite)
:: Description: Quick launcher script with execution policy bypass.
:: ============================================================================
title ProNetwork11 - Windows 11 Network Diagnostics [by diogeneslite]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pronetwork11.ps1" %*
