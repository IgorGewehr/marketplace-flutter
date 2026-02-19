# ☁️ Cloud Functions Examples

Este documento contém exemplos de Cloud Functions necessárias para o backend do marketplace.

## 📦 Setup

```bash
# Inicializar Firebase Functions
firebase init functions

# Instalar dependências
cd functions
npm install firebase-admin firebase-functions mercadopago node-fetch
```

## 🔧 Configuração

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const mercadopago = require('mercadopago');

admin.initializeApp();
const db = admin.firestore();

// Configurar Mercado Pago
mercadopago.configure({
  access_token: functions.config().mercadopago.access_token
});

// Configurar timezone
process.env.TZ = 'America/Sao_Paulo';
```

## 💳 Split Payment Functions

### 1. Criar Payment com Split
```javascript
exports.createSplitPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }

  const { orderId, paymentMethod, installments } = data;

  try {
    // Buscar ordem
    const orderDoc = await db.collection('orders').doc(orderId).get();
    const order = orderDoc.data();

    // Buscar tenant para pegar Mercado Pago ID
    const tenantDoc = await db.collection('tenants').doc(order.tenantId).get();
    const tenant = tenantDoc.data();

    // Calcular split
    const platformFee = order.total * 0.1; // 10%
    const sellerAmount = order.total - platformFee;

    // Criar pagamento
    const payment = await mercadopago.payment.create({
      transaction_amount: order.total,
      description: `Pedido #${order.orderNumber} - NexMarket`,
      payment_method_id: paymentMethod,
      installments: installments || 1,
      payer: {
        email: order.buyerEmail,
      },
      application_fee: platformFee,
      metadata: {
        order_id: orderId,
        tenant_id: order.tenantId,
      },
      notification_url: `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/handleMercadoPagoWebhook`,
    });

    // Atualizar ordem
    await orderDoc.ref.update({
      'paymentSplit.mpPaymentId': payment.body.id,
      'paymentSplit.platformFeeAmount': platformFee,
      'paymentSplit.sellerAmount': sellerAmount,
      'paymentSplit.status': 'pending',
      paymentGatewayId: payment.body.id.toString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      paymentId: payment.body.id,
      status: payment.body.status,
    };
  } catch (error) {
    console.error('Erro ao criar split payment:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

### 2. Webhook do Mercado Pago
```javascript
exports.handleMercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { type, data } = req.body;

  if (type === 'payment') {
    try {
      // Buscar informações do pagamento
      const payment = await mercadopago.payment.get(data.id);
      const orderId = payment.body.metadata.order_id;

      // Buscar ordem
      const orderDoc = await db.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        console.error('Ordem não encontrada:', orderId);
        return res.status(404).send('Order not found');
      }

      // Atualizar status do pagamento
      const paymentStatus = payment.body.status === 'approved' ? 'paid' : 'failed';

      await orderDoc.ref.update({
        paymentStatus: paymentStatus,
        'paymentSplit.status': payment.body.status === 'approved' ? 'held' : 'failed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Se pagamento aprovado, criar QR Code de entrega
      if (payment.body.status === 'approved') {
        const qrCodeId = await generateDeliveryQRCode(orderId);
        await orderDoc.ref.update({ qrCodeId });
      }

      return res.status(200).send('OK');
    } catch (error) {
      console.error('Erro ao processar webhook:', error);
      return res.status(500).send('Internal Server Error');
    }
  }

  res.status(200).send('OK');
});
```

### 3. Liberar Pagamento (Scheduled Function)
```javascript
exports.releasePayments = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('America/Sao_Paulo')
  .onRun(async (context) => {
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000)
    );

    // Buscar pedidos para liberar pagamento
    const ordersSnapshot = await db.collection('orders')
      .where('deliveryConfirmedAt', '<=', twentyFourHoursAgo)
      .where('paymentReleasedAt', '==', null)
      .where('paymentStatus', '==', 'paid')
      .get();

    const promises = ordersSnapshot.docs.map(async (doc) => {
      const order = doc.data();

      try {
        // Atualizar status no Mercado Pago (se necessário)
        // mercadopago.payment.capture(order.paymentGatewayId);

        // Atualizar ordem
        await doc.ref.update({
          paymentReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
          'paymentSplit.status': 'released',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Enviar notificação para vendedor
        await sendNotification(
          order.tenantId,
          'Pagamento liberado!',
          `O pagamento do pedido #${order.orderNumber} foi liberado.`,
          'payment_released'
        );

        console.log(`Pagamento liberado para ordem ${doc.id}`);
      } catch (error) {
        console.error(`Erro ao liberar pagamento da ordem ${doc.id}:`, error);
      }
    });

    await Promise.all(promises);
    console.log(`${promises.length} pagamentos processados`);
  });
```

## 🔐 QR Code de Entrega

### 1. Gerar QR Code
```javascript
const crypto = require('crypto');

async function generateDeliveryQRCode(orderId) {
  const qrCodeId = crypto.randomBytes(16).toString('hex');

  // Salvar QR Code no Firestore
  await db.collection('qr_codes').doc(qrCodeId).set({
    orderId,
    used: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 dias
    ),
  });

  return qrCodeId;
}

exports.generateDeliveryQRCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }

  const { orderId } = data;
  const qrCodeId = await generateDeliveryQRCode(orderId);

  return { qrCodeId };
});
```

### 2. Validar e Confirmar Entrega
```javascript
exports.confirmDelivery = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }

  const { qrCodeId } = data;
  const userId = context.auth.uid;

  try {
    // Buscar QR Code
    const qrCodeDoc = await db.collection('qr_codes').doc(qrCodeId).get();

    if (!qrCodeDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'QR Code inválido');
    }

    const qrCode = qrCodeDoc.data();

    if (qrCode.used) {
      throw new functions.https.HttpsError('failed-precondition', 'QR Code já foi usado');
    }

    // Verificar expiração
    if (qrCode.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError('failed-precondition', 'QR Code expirado');
    }

    // Buscar ordem
    const orderDoc = await db.collection('orders').doc(qrCode.orderId).get();
    const order = orderDoc.data();

    // Verificar se usuário é o comprador
    if (order.buyerUserId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Você não é o comprador deste pedido');
    }

    // Marcar QR Code como usado
    await qrCodeDoc.ref.update({
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      usedBy: userId,
    });

    // Atualizar ordem
    const deliveryConfirmedAt = admin.firestore.FieldValue.serverTimestamp();
    const paymentReleaseDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await orderDoc.ref.update({
      deliveryConfirmedAt,
      'paymentSplit.heldUntil': admin.firestore.Timestamp.fromDate(paymentReleaseDate),
      status: 'delivered',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Enviar notificações
    await sendNotification(
      userId,
      'Entrega confirmada!',
      'O pagamento será liberado para o vendedor em 24 horas.',
      'delivery_confirmation'
    );

    await sendNotification(
      order.tenantId,
      'Entrega confirmada!',
      `O pedido #${order.orderNumber} foi confirmado pelo comprador.`,
      'delivery_confirmation'
    );

    return {
      success: true,
      message: 'Entrega confirmada com sucesso!',
      paymentReleaseDate: paymentReleaseDate.toISOString(),
    };
  } catch (error) {
    console.error('Erro ao confirmar entrega:', error);
    throw error;
  }
});
```

## ⭐ Reviews Functions

### 1. Verificar se usuário pode avaliar
```javascript
exports.canUserReview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }

  const { targetId, targetType } = data;
  const userId = context.auth.uid;

  try {
    // Verificar se já avaliou
    const existingReview = await db.collection('reviews')
      .where('userId', '==', userId)
      .where('targetId', '==', targetId)
      .where('targetType', '==', targetType)
      .get();

    if (!existingReview.empty) {
      return { canReview: false, reason: 'already_reviewed' };
    }

    // Verificar se comprou (para produtos)
    if (targetType === 'product') {
      const ordersSnapshot = await db.collection('orders')
        .where('buyerUserId', '==', userId)
        .where('status', '==', 'delivered')
        .get();

      const hasPurchased = ordersSnapshot.docs.some(doc => {
        const order = doc.data();
        return order.items.some(item => item.productId === targetId);
      });

      if (!hasPurchased) {
        return { canReview: false, reason: 'not_purchased' };
      }
    }

    return { canReview: true };
  } catch (error) {
    console.error('Erro ao verificar permissão de review:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

### 2. Atualizar estatísticas após review
```javascript
exports.updateReviewStats = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap, context) => {
    const review = snap.data();
    const { targetId, targetType, rating } = review;

    try {
      if (targetType === 'product') {
        // Atualizar estatísticas do produto
        const productRef = db.collection('products').doc(targetId);
        const productDoc = await productRef.get();
        const product = productDoc.data();

        const currentStats = product.marketplaceStats || {
          rating: 0,
          reviewCount: 0,
        };

        const newReviewCount = currentStats.reviewCount + 1;
        const newRating = (
          (currentStats.rating * currentStats.reviewCount + rating) /
          newReviewCount
        ).toFixed(1);

        await productRef.update({
          'marketplaceStats.rating': parseFloat(newRating),
          'marketplaceStats.reviewCount': newReviewCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else if (targetType === 'seller') {
        // Atualizar estatísticas do vendedor
        const tenantRef = db.collection('tenants').doc(targetId);
        const tenantDoc = await tenantRef.get();
        const tenant = tenantDoc.data();

        const currentStats = tenant.marketplace || {
          rating: 0,
          totalReviews: 0,
        };

        const newReviewCount = currentStats.totalReviews + 1;
        const newRating = (
          (currentStats.rating * currentStats.totalReviews + rating) /
          newReviewCount
        ).toFixed(1);

        await tenantRef.update({
          'marketplace.rating': parseFloat(newRating),
          'marketplace.totalReviews': newReviewCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log(`Estatísticas atualizadas para ${targetType} ${targetId}`);
    } catch (error) {
      console.error('Erro ao atualizar estatísticas:', error);
    }
  });
```

## ❤️ Wishlist Functions

### 1. Notificar queda de preço
```javascript
exports.notifyPriceDrops = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change, context) => {
    const oldProduct = change.before.data();
    const newProduct = change.after.data();
    const productId = context.params.productId;

    // Verificar se preço caiu
    if (newProduct.price >= oldProduct.price) {
      return null;
    }

    try {
      // Buscar wishlists que contém este produto
      const wishlistsSnapshot = await db.collection('wishlists')
        .where('items', 'array-contains', {
          productId: productId,
          notifyOnPriceDrops: true,
        })
        .get();

      const notifications = wishlistsSnapshot.docs.map(async (doc) => {
        const userId = doc.id;
        const discount = ((oldProduct.price - newProduct.price) / oldProduct.price * 100).toFixed(0);

        await sendNotification(
          userId,
          'Queda de preço! 🎉',
          `${newProduct.name} está ${discount}% mais barato!`,
          'price_drop_alert',
          { productId }
        );
      });

      await Promise.all(notifications);
      console.log(`${notifications.length} notificações enviadas para queda de preço`);
    } catch (error) {
      console.error('Erro ao notificar queda de preço:', error);
    }
  });
```

## 📍 Geolocalização Functions

### 1. Notificar produtos próximos
```javascript
exports.notifyNearbyProducts = functions.firestore
  .document('products/{productId}')
  .onCreate(async (snap, context) => {
    const product = snap.data();
    const productId = context.params.productId;

    if (!product.location?.coordinates) {
      return null;
    }

    try {
      // Buscar usuários na mesma cidade
      const usersSnapshot = await db.collection('users')
        .where('addresses', 'array-contains', {
          city: product.location.city,
        })
        .get();

      const notifications = usersSnapshot.docs.map(async (doc) => {
        const user = doc.data();

        // Verificar preferências de notificação
        if (user.preferences?.notifyPromotions) {
          await sendNotification(
            doc.id,
            'Novo produto perto de você! 📍',
            `${product.name} - ${product.location.neighborhood}`,
            'new_product_nearby',
            { productId }
          );
        }
      });

      await Promise.all(notifications);
      console.log(`${notifications.length} notificações enviadas`);
    } catch (error) {
      console.error('Erro ao notificar produtos próximos:', error);
    }
  });
```

## 📊 Ad Promotions Functions

### 1. Gerenciar promoções ativas
```javascript
exports.managePromotions = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('America/Sao_Paulo')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    try {
      // Ativar promoções que devem começar
      const toActivate = await db.collection('ad_promotions')
        .where('status', '==', 'pending')
        .where('paymentStatus', '==', 'paid')
        .where('startDate', '<=', now)
        .get();

      for (const doc of toActivate.docs) {
        await doc.ref.update({
          status: 'active',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Desativar promoções que terminaram
      const toComplete = await db.collection('ad_promotions')
        .where('status', '==', 'active')
        .where('endDate', '<=', now)
        .get();

      for (const doc of toComplete.docs) {
        await doc.ref.update({
          status: 'completed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log(`Ativadas: ${toActivate.size}, Completadas: ${toComplete.size}`);
    } catch (error) {
      console.error('Erro ao gerenciar promoções:', error);
    }
  });
```

## 📧 Notificações Helper

```javascript
async function sendNotification(userId, title, body, type, data = {}) {
  try {
    // Buscar tokens FCM do usuário
    const userDoc = await db.collection('users').doc(userId).get();
    const user = userDoc.data();

    if (!user?.fcmTokens || user.fcmTokens.length === 0) {
      console.log(`Usuário ${userId} não tem tokens FCM`);
      return;
    }

    // Enviar notificação para todos os tokens
    const messages = user.fcmTokens.map(token => ({
      token,
      notification: { title, body },
      data: {
        type,
        ...data,
      },
    }));

    await admin.messaging().sendAll(messages);

    // Salvar notificação no banco
    await db.collection('notifications').add({
      userId,
      title,
      body,
      type,
      data,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Notificação enviada para ${userId}`);
  } catch (error) {
    console.error('Erro ao enviar notificação:', error);
  }
}
```

## 🚀 Deploy

```bash
# Configurar variáveis de ambiente
firebase functions:config:set \
  mercadopago.access_token="YOUR_MP_ACCESS_TOKEN" \
  mercadopago.public_key="YOUR_MP_PUBLIC_KEY"

# Deploy
firebase deploy --only functions

# Ver logs
firebase functions:log
```

---

**Última atualização**: 2025-02-09
