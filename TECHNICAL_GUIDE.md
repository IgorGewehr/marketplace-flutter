# 🔧 Guia Técnico - Flutter Marketplace

## Arquitetura

O projeto segue Clean Architecture com a seguinte estrutura:

```
lib/
├── core/
│   ├── constants/          # Constantes da aplicação
│   ├── theme/              # Tema e estilos
│   ├── utils/              # Utilitários e helpers
│   └── errors/             # Tratamento de erros
├── data/
│   ├── models/             # Modelos de dados
│   └── repositories/       # Implementações de repositórios
├── domain/
│   └── repositories/       # Interfaces de repositórios
└── presentation/
    ├── providers/          # Gerenciamento de estado (Riverpod)
    ├── screens/            # Telas da aplicação
    └── widgets/            # Widgets reutilizáveis
```

---

## 🆕 Novos Modelos

### 1. ReviewModel
**Localização**: `lib/data/models/review_model.dart`

```dart
// Criar review de produto
final review = ReviewModel(
  id: uuid.v4(),
  targetId: productId,
  targetType: 'product',
  userId: currentUser.id,
  userName: currentUser.displayName,
  rating: 5.0,
  comment: 'Produto excelente!',
  isVerifiedPurchase: true,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Criar review de vendedor
final sellerReview = ReviewModel(
  id: uuid.v4(),
  targetId: tenantId,
  targetType: 'seller',
  userId: currentUser.id,
  userName: currentUser.displayName,
  rating: 4.5,
  comment: 'Vendedor muito atencioso!',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

**Firestore Path**: `/reviews/{reviewId}`

**Índices necessários**:
```
- targetId, targetType, rating (desc)
- targetId, isVerifiedPurchase, createdAt (desc)
- userId, targetId
```

---

### 2. WishlistModel
**Localização**: `lib/data/models/wishlist_model.dart`

```dart
// Adicionar item à wishlist
final wishlistItem = WishlistItem(
  productId: product.id,
  productName: product.name,
  price: product.price,
  compareAtPrice: product.compareAtPrice,
  imageUrl: product.mainImageUrl,
  tenantId: product.tenantId,
  tenantName: seller.name,
  notifyOnPriceDrops: true,
  notifyOnAvailability: true,
  addedAt: DateTime.now(),
);

// Adicionar à wishlist do usuário
wishlist = wishlist.copyWith(
  items: [...wishlist.items, wishlistItem],
);
```

**Firestore Path**: `/wishlists/{userId}`

**Cloud Function necessária**:
```javascript
// Monitorar mudanças de preço
exports.checkPriceDrops = functions.firestore
  .document('products/{productId}')
  .onUpdate((change, context) => {
    const newPrice = change.after.data().price;
    const oldPrice = change.before.data().price;

    if (newPrice < oldPrice) {
      // Notificar usuários com produto na wishlist
    }
  });
```

---

### 3. ReportModel
**Localização**: `lib/data/models/report_model.dart`

```dart
// Criar denúncia
final report = ReportModel(
  id: uuid.v4(),
  reporterUserId: currentUser.id,
  targetId: productId,
  targetType: 'product',
  reason: ReportReasons.prohibitedItem,
  details: 'Este produto não deveria estar à venda...',
  evidenceImages: ['url1', 'url2'],
  status: 'pending',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

**Firestore Path**: `/reports/{reportId}`

**Security Rules**:
```javascript
match /reports/{reportId} {
  // Qualquer usuário autenticado pode criar
  allow create: if request.auth != null;

  // Apenas admin pode ler/atualizar
  allow read, update: if isAdmin();
}
```

---

### 4. AdPromotionModel
**Localização**: `lib/data/models/ad_promotion_model.dart`

```dart
// Criar promoção
final promotion = AdPromotionModel(
  id: uuid.v4(),
  tenantId: currentTenant.id,
  targetId: productId,
  targetType: 'product',
  promotionType: PromotionTypes.cityTop,
  location: AdPromotionLocation(
    city: 'São Paulo',
    state: 'SP',
    categoryId: categoryId,
  ),
  pricePerDay: 50.0,
  totalPrice: 350.0, // 7 dias
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(days: 7)),
  status: 'pending',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

**Firestore Path**: `/ad_promotions/{promotionId}`

**Cloud Function necessária**:
```javascript
// Ativar/desativar promoções baseado em datas
exports.managePromotions = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // Ativar promoções que começam agora
    // Desativar promoções que terminaram
  });
```

---

## 🔄 Modelos Atualizados

### OrderModel
**Novos campos**:
```dart
final String? qrCodeId;                    // QR Code para confirmação
final DateTime? deliveryConfirmedAt;       // Data de confirmação
final DateTime? paymentReleasedAt;         // Data de liberação
final OrderPaymentSplit? paymentSplit;     // Split payment
```

**Uso**:
```dart
// Criar ordem com split payment
final order = OrderModel(
  // ... campos existentes
  qrCodeId: generatedQrCodeId,
  paymentSplit: OrderPaymentSplit(
    platformFeePercentage: 10.0,
    platformFeeAmount: total * 0.1,
    sellerAmount: total * 0.9,
    mpPaymentId: mercadoPagoPaymentId,
    status: 'pending',
    heldUntil: DateTime.now().add(Duration(hours: 24)),
  ),
);
```

**Cloud Function - Liberar pagamento**:
```javascript
exports.releasePayments = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // Buscar pedidos com deliveryConfirmedAt há mais de 24h
    const ordersToRelease = await db.collection('orders')
      .where('deliveryConfirmedAt', '<=', twentyFourHoursAgo)
      .where('paymentReleasedAt', '==', null)
      .get();

    for (const doc of ordersToRelease.docs) {
      // Chamar API do Mercado Pago para liberar pagamento
      await releaseSplitPayment(doc.data());

      // Atualizar ordem
      await doc.ref.update({
        paymentReleasedAt: now,
        'paymentSplit.status': 'released'
      });
    }
  });
```

### ProductModel
**Novos campos**:
```dart
final ProductLocation? location;  // Geolocalização
```

**Uso**:
```dart
final product = ProductModel(
  // ... campos existentes
  location: ProductLocation(
    coordinates: CoordinatesModel(
      latitude: -23.550520,
      longitude: -46.633308,
    ),
    city: 'São Paulo',
    state: 'SP',
    neighborhood: 'Vila Mariana',
    zipCode: '04101-300',
  ),
);
```

**Firestore Geoqueries**:
```dart
// Usar pacote geoflutterfire para buscar por proximidade
import 'package:geoflutterfire/geoflutterfire.dart';

final geo = Geoflutterfire();
final center = geo.point(
  latitude: userLat,
  longitude: userLng,
);

// Buscar produtos em um raio de 10km
final stream = geo.collection(
  collectionRef: firestore.collection('products'),
).within(
  center: center,
  radius: 10, // km
  field: 'location.coordinates',
);
```

### TenantModel - DeliveryOption
**Novos campos**:
```dart
final String? label;
final Map<String, double>? neighborhoodFees;
final String? motoboyProvider;
final Map<String, dynamic>? providerConfig;
```

**Uso**:
```dart
// Configurar opções de entrega
final deliveryOptions = [
  DeliveryOption(
    type: DeliveryTypes.pickupInPerson,
    label: 'Retirada no local',
  ),
  DeliveryOption(
    type: DeliveryTypes.sellerDelivery,
    label: 'Entrega própria',
    neighborhoodFees: {
      'Vila Mariana': 10.0,
      'Moema': 15.0,
      'Ipiranga': 12.0,
    },
    deliveryRadius: 5,
    estimatedTime: '30-60 min',
  ),
  DeliveryOption(
    type: DeliveryTypes.motoboy,
    motoboyProvider: 'Loggi',
    providerConfig: {
      'apiKey': 'xxx',
    },
  ),
];
```

---

## 🎨 Widgets

### WhatsAppButton
**Localização**: `lib/presentation/widgets/shared/whatsapp_button.dart`

```dart
// Botão padrão
WhatsAppButton(
  phoneNumber: '+5511999999999',
  message: 'Olá, vi seu produto no NexMarket!',
  label: 'Falar com vendedor',
)

// Botão compacto (ícone apenas)
WhatsAppButton(
  phoneNumber: seller.whatsapp,
  isCompact: true,
  onBeforeLaunch: () {
    analytics.logEvent('whatsapp_contact');
  },
)

// FAB flutuante
WhatsAppFab(
  phoneNumber: seller.whatsapp,
  message: 'Olá! Tenho interesse no produto.',
)

// Função helper
await launchWhatsApp(
  phoneNumber: '+5511999999999',
  message: 'Mensagem',
  context: context,
);
```

---

## 🔐 Firestore Security Rules

### Reviews
```javascript
match /reviews/{reviewId} {
  allow read: if true;

  allow create: if
    request.auth != null &&
    request.resource.data.userId == request.auth.uid &&
    // Verificar se tem compra verificada (fazer function)
    canUserReview(request.resource.data.targetId);

  allow update: if
    request.auth.uid == resource.data.userId ||
    isSeller(resource.data.targetId); // Para resposta do vendedor

  allow delete: if
    request.auth.uid == resource.data.userId ||
    isAdmin();
}
```

### Wishlists
```javascript
match /wishlists/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

### Reports
```javascript
match /reports/{reportId} {
  allow create: if request.auth != null;
  allow read, update: if isAdmin();
}
```

### Ad Promotions
```javascript
match /ad_promotions/{promotionId} {
  allow read: if
    resource.data.status == 'active' ||
    request.auth.uid == resource.data.tenantId;

  allow create: if
    request.auth != null &&
    isTenantOwner(request.resource.data.tenantId);

  allow update: if
    request.auth.uid == resource.data.tenantId ||
    isAdmin();
}
```

---

## 🔌 Integração Mercado Pago

### Setup
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

final mpPublicKey = dotenv.env['MP_PUBLIC_KEY']!;
final mpAccessToken = dotenv.env['MP_ACCESS_TOKEN']!;
```

### Split Payment
```dart
// Backend (Cloud Function)
const mercadopago = require('mercadopago');

mercadopago.configure({
  access_token: process.env.MP_ACCESS_TOKEN
});

async function createSplitPayment(order) {
  const payment = await mercadopago.payment.create({
    transaction_amount: order.total,
    description: `Pedido #${order.orderNumber}`,
    payment_method_id: 'pix',
    payer: {
      email: order.buyerEmail,
    },
    // Split payment
    application_fee: order.total * 0.1, // 10% para plataforma
    // O resto vai para o vendedor conectado
  });

  return payment;
}
```

---

## 📊 Analytics e Tracking

### Eventos importantes
```dart
// Review criado
analytics.logEvent(
  name: 'review_created',
  parameters: {
    'target_type': 'product',
    'rating': 5,
  },
);

// Produto adicionado à wishlist
analytics.logEvent(
  name: 'add_to_wishlist',
  parameters: {
    'product_id': productId,
    'price': price,
  },
);

// Promoção criada
analytics.logEvent(
  name: 'promotion_created',
  parameters: {
    'type': 'city_top',
    'duration_days': 7,
    'total_price': 350.0,
  },
);

// WhatsApp clicado
analytics.logEvent(
  name: 'whatsapp_contact',
  parameters: {
    'source': 'product_details',
  },
);
```

---

## 🧪 Testes

### Unit Tests
```dart
// test/models/review_model_test.dart
test('ReviewModel should serialize to JSON correctly', () {
  final review = ReviewModel(/* ... */);
  final json = review.toJson();

  expect(json['rating'], 5.0);
  expect(json['isVerifiedPurchase'], true);
});

// test/models/order_model_test.dart
test('Order should calculate payment hold correctly', () {
  final order = OrderModel(/* ... */);
  order = order.copyWith(
    deliveryConfirmedAt: DateTime.now(),
  );

  expect(order.isPaymentOnHold, true);
  expect(order.isPaymentReleased, false);
});
```

### Integration Tests
```dart
// integration_test/wishlist_test.dart
testWidgets('Add product to wishlist', (tester) async {
  // Setup
  await tester.pumpWidget(MyApp());

  // Navigate to product
  await tester.tap(find.byType(ProductCard).first);
  await tester.pumpAndSettle();

  // Tap favorite button
  await tester.tap(find.byIcon(Icons.favorite_border));
  await tester.pumpAndSettle();

  // Verify
  expect(find.byIcon(Icons.favorite), findsOneWidget);
  expect(find.text('Adicionado aos favoritos'), findsOneWidget);
});
```

---

## 🚀 Deploy

### 1. Configurar Firebase
```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Inicializar projeto
firebase init

# Deploy functions
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 2. Configurar Mercado Pago
1. Criar conta no Mercado Pago
2. Obter credenciais de produção
3. Configurar webhook URL
4. Adicionar domínio autorizado

### 3. Deploy do App
```bash
# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release
```

---

## 📝 Checklist de Produção

- [ ] Configurar Firebase (Auth, Firestore, Storage, Messaging)
- [ ] Adicionar índices do Firestore
- [ ] Configurar Security Rules
- [ ] Deploy das Cloud Functions
- [ ] Configurar Mercado Pago (produção)
- [ ] Testar split payment
- [ ] Configurar webhook do Mercado Pago
- [ ] Implementar KYC (escolher provider)
- [ ] Configurar Google Maps API
- [ ] Testar notificações push
- [ ] Configurar Analytics
- [ ] Testar QR Code de entrega
- [ ] Revisar políticas de privacidade
- [ ] Testar todo o fluxo de compra
- [ ] Realizar testes de carga
- [ ] Configurar monitoramento (Crashlytics)

---

## 🆘 Troubleshooting

### WhatsApp não abre
- Verificar se `url_launcher` está configurado corretamente
- Adicionar permissões no AndroidManifest.xml
- Verificar Info.plist no iOS

### Geolocalização não funciona
- Adicionar permissões de localização
- Verificar Google Maps API key
- Testar em dispositivo real (não funciona em alguns simuladores)

### Split payment falha
- Verificar credenciais do Mercado Pago
- Verificar se conta tem permissão de marketplace
- Checar logs da Cloud Function

---

**Última atualização**: 2025-02-09
