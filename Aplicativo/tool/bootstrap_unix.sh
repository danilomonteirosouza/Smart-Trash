#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter 3.47+ nao foi encontrado no PATH." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] Flutter doctor..."
flutter doctor

echo "[2/6] Limpando artefatos..."
flutter clean

echo "[3/6] Instalando dependencias..."
flutter pub get

echo "[4/6] Aplicando configuracoes nativas..."
dart run tool/configure_platforms.dart

echo "[5/6] Analise estatica..."
flutter analyze

echo "[6/6] Testes..."
flutter test

echo "Lixeira Inteligente preparada. Execute: flutter run"
