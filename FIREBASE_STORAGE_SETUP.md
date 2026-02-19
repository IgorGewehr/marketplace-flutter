# 📦 Configuração do Firebase Storage

## Passo 1: Ativar Firebase Storage

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione seu projeto
3. No menu lateral, clique em **"Storage"**
4. Clique em **"Começar"**
5. Escolha a localização (recomendado: **us-central1** ou **southamerica-east1** para Brasil)
6. Clique em **"Concluído"**

---

## Passo 2: Configurar Regras de Segurança

No Firebase Console, vá para **Storage → Rules** e cole as regras abaixo:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isValidImage() {
      return request.resource.size < 5 * 1024 * 1024 // Max 5MB
          && request.resource.contentType.matches('image/.*');
    }

    // Product images - only authenticated sellers can upload
    match /products/{productId}/{imageId} {
      allow read: if true; // Anyone can read
      allow write: if isAuthenticated()
                   && isValidImage();
      allow delete: if isAuthenticated();
    }

    // User profile images
    match /users/{userId}/profile/{imageId} {
      allow read: if true;
      allow write: if isAuthenticated()
                   && isOwner(userId)
                   && isValidImage();
      allow delete: if isAuthenticated() && isOwner(userId);
    }

    // Default deny all other paths
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**Clique em "Publicar"**

---

## Passo 3: Configurar CORS (opcional, para web)

Se você for usar a versão web do app, configure o CORS:

1. Instale o Google Cloud SDK: https://cloud.google.com/sdk/docs/install
2. Execute:
```bash
gcloud auth login
```
3. Crie um arquivo `cors.json`:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "maxAgeSeconds": 3600
  }
]
```
4. Execute:
```bash
gsutil cors set cors.json gs://SEU-BUCKET-NAME.appspot.com
```

---

## Passo 4: Testar Upload

1. Execute `flutter pub get` no terminal
2. Rode o app
3. Faça login como vendedor
4. Vá em "Meus Produtos" → "Novo Produto"
5. Adicione fotos
6. Salve o produto
7. Verifique no Firebase Console → Storage se as imagens foram enviadas

---

## 📊 Limites do Firebase Storage (Plano Gratuito)

- **5 GB** de armazenamento
- **1 GB/dia** de download
- **20.000** uploads por dia
- **50.000** downloads por dia

Para aumentar, atualize para o plano **Blaze** (paga apenas o que usar).

---

## 🔧 Troubleshooting

### Erro: "Firebase Storage bucket not found"
- Certifique-se de ter ativado o Storage no console
- Verifique se o app está conectado ao projeto correto

### Erro: "Permission denied"
- Verifique as regras de segurança
- Certifique-se de que o usuário está autenticado

### Erro: "File size exceeds maximum allowed size"
- A compressão automática está limitando imagens a 5MB
- Ajuste o limite em `image_upload_service.dart` se necessário

---

## ✅ Próximo Passo

Execute no terminal:
```bash
flutter pub get
```

E teste o upload de imagens! 🚀
