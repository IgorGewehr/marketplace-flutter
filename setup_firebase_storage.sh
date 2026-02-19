#!/bin/bash

# Script de setup do Firebase Storage para Flutter Marketplace
# Autor: Claude Code
# Data: 2026-02-10

echo "🚀 Configurando Firebase Storage..."
echo ""

# 1. Instalar dependências
echo "📦 Instalando dependências do Flutter..."
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ Dependências instaladas com sucesso!"
else
    echo "❌ Erro ao instalar dependências"
    exit 1
fi

echo ""

# 2. Verificar se Firebase está configurado
echo "🔍 Verificando configuração do Firebase..."

if [ -f "lib/firebase_options.dart" ]; then
    echo "✅ firebase_options.dart encontrado!"
else
    echo "⚠️  firebase_options.dart não encontrado!"
    echo "   Execute: flutterfire configure"
    echo ""
fi

# 3. Instruções
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo ""
echo "1. Acesse o Firebase Console:"
echo "   https://console.firebase.google.com/"
echo ""
echo "2. Ative o Firebase Storage:"
echo "   - Clique em 'Storage' no menu lateral"
echo "   - Clique em 'Começar'"
echo "   - Escolha a localização: southamerica-east1 (Brasil)"
echo ""
echo "3. Configure as regras de segurança:"
echo "   - Vá para Storage → Rules"
echo "   - Cole as regras do arquivo: FIREBASE_STORAGE_SETUP.md"
echo "   - Clique em 'Publicar'"
echo ""
echo "4. Teste o upload:"
echo "   - Execute: flutter run"
echo "   - Faça login como vendedor"
echo "   - Crie um produto com fotos"
echo ""
echo "✅ Setup concluído! Leia FIREBASE_STORAGE_SETUP.md para mais detalhes."
echo ""
