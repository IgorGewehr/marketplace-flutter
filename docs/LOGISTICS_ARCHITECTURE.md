# Arquitetura de Logística — NexMarket Regional (Concórdia/SC)

> **Escopo:** Marketplace regional hiperfocado em Concórdia e cidades próximas (~60km raio).
> **Modelo:** Frota própria (motoboys e motoristas contratados). Sem Correios, sem transportadoras terceirizadas.
> **Data:** Fevereiro 2026

---

## Índice

1. [Visão Geral da Estratégia](#1-visão-geral-da-estratégia)
2. [Estado Atual do App](#2-estado-atual-do-app)
3. [Sistema de Zonas de Entrega](#3-sistema-de-zonas-de-entrega)
4. [Algoritmo de Precificação de Frete](#4-algoritmo-de-precificação-de-frete)
5. [Algoritmo de Prioridade e Roteirização](#5-algoritmo-de-prioridade-e-roteirização)
6. [Modelo de Dados — Novas Coleções e Campos](#6-modelo-de-dados--novas-coleções-e-campos)
7. [Backend — Novos Endpoints](#7-backend--novos-endpoints)
8. [Flutter — Novos Providers e Telas](#8-flutter--novos-providers-e-telas)
9. [Fluxo Completo do Pedido (Novo)](#9-fluxo-completo-do-pedido-novo)
10. [Pontos de Retirada](#10-pontos-de-retirada)
11. [Painel do Entregador (Futuro)](#11-painel-do-entregador-futuro)
12. [Firestore Rules e Indexes](#12-firestore-rules-e-indexes)
13. [Casos de Borda e Tratamento de Erros](#13-casos-de-borda-e-tratamento-de-erros)
14. [Fases de Implementação](#14-fases-de-implementação)
15. [Métricas e Monitoramento](#15-métricas-e-monitoramento)

---

## 1. Visão Geral da Estratégia

### 1.1 Por que frota própria

| Fator | Correios/Transportadora | Frota Própria |
|---|---|---|
| Entrega intra-cidade | 3-5 dias (PAC) | **Same-day** |
| Custo Concórdia→Concórdia | R$15-18 | **R$5-8** |
| Custo Concórdia→Seara | R$16-20 | **R$10-15** |
| Controle da experiência | Nenhum | **Total** |
| Rastreamento | Código manual | **GPS real-time (futuro)** |
| Complexidade de integração | Alta (API Correios/ME) | **Baixa (tabela interna)** |
| Escalabilidade nacional | Sim | Não (proposital) |

### 1.2 Área de cobertura

Raio máximo a partir de Concórdia: **~60km** (inclui Capinzal).

```
                    Ipumirim (35km N)
                        │
          Lindóia do Sul (20km NO)
                │       │
                ├───CONCÓRDIA───┤
                │    (centro)   │
        Peritiba│               │Seara (25km L)
        (22km O)│               │
                │               │
          Piratuba (45km SO)    Itá (40km SE)
                                │
                          Capinzal (55km S)
```

### 1.3 Premissas de volume inicial

- **Fase de lançamento:** 5-15 pedidos/dia
- **Frota inicial:** 2-3 motoboys + 1 motorista (van para volumes maiores)
- **Janelas de despacho:** 2 por dia (manhã e tarde)
- **Cutoff same-day:** pedidos até 14h
- **Horário de operação:** 08h-18h (seg-sex), 08h-12h (sáb)

---

## 2. Estado Atual do App

### 2.1 O que já existe e será aproveitado

| Componente | Arquivo | Status |
|---|---|---|
| `DeliveryOption` model (4 tipos) | `lib/data/models/tenant_model.dart` | ✅ Existe, precisa ativar |
| `deliveryFee` no `OrderModel` | `lib/data/models/order_model.dart` | ✅ Campo existe (sempre 0) |
| `deliveryAddress` no order | `lib/data/models/order_model.dart` | ✅ Funcional |
| `AddressModel` com coordinates | `lib/data/models/address_model.dart` | ✅ Funcional |
| `estimatedDelivery` no order | `lib/data/models/order_model.dart` | ✅ Campo existe (nunca populado) |
| `trackingCode` / `shippingCompany` | `lib/data/models/order_model.dart` | ✅ Funcional |
| QR Code de confirmação de entrega | `functions/src/delivery/qrcode.ts` | ✅ Funcional |
| Payment hold 24h | `functions/src/scheduled/release-payments.ts` | ✅ Funcional |
| Seleção de endereço no checkout | `lib/presentation/screens/checkout/checkout_screen.dart` | ✅ Funcional |
| `ProductLocation` com coordinates | `lib/data/models/product_model.dart` | ✅ Existe |
| `CoordinatesModel` (lat/lng) | `lib/data/models/address_model.dart` | ✅ Funcional |
| Status flow (pending→delivered) | `lib/presentation/widgets/orders/order_timeline.dart` | ✅ Funcional |
| `DeliveryTypes` constants | `lib/core/constants/marketplace_constants.dart` | ✅ Definidas |
| `neighborhoodFees` em DeliveryOption | `lib/data/models/tenant_model.dart` | ✅ Campo existe (nunca usado) |
| `deliveryRadius` em DeliveryOption | `lib/data/models/tenant_model.dart` | ✅ Campo existe (nunca usado) |
| `freeDeliveryMinimum` em DeliveryOption | `lib/data/models/tenant_model.dart` | ✅ Campo existe (nunca usado) |

### 2.2 O que precisa mudar

| Componente | Mudança Necessária |
|---|---|
| `deliveryFee` no backend | Deixa de ser hardcoded `0` → calculado pelo algoritmo |
| `total` no order | Passa a incluir `deliveryFee` real |
| Checkout screen | Novo step: seleção de método de entrega + exibição do frete |
| `CheckoutState` | Novos campos: `deliveryOption`, `deliveryFee`, `estimatedDelivery` |
| `payments.ts` (POST /api/orders) | Receber e validar `deliveryOption` + calcular frete server-side |
| `cart_summary.dart` | Exibir frete calculado (remove "combinar com vendedor") |
| Tenant address | String simples → `AddressModel` completo com coordinates |
| Product model | Adicionar `weight` e `shippingCategory` |
| Seller onboarding | Coletar endereço completo com CEP (para cálculo de distância) |

### 2.3 O que será criado do zero

| Componente | Descrição |
|---|---|
| Coleção `delivery_zones` | Zonas de entrega com preços e prazos |
| Coleção `pickup_points` | Pontos de retirada parceiros |
| Coleção `delivery_routes` | Rotas agrupadas para despacho |
| `functions/src/routes/shipping.ts` | Endpoints de cálculo de frete e gestão de entregas |
| `shipping_provider.dart` | Provider Riverpod para opções de frete |
| Tela de seleção de entrega | Step no checkout para escolher método/zona |
| Painel de rotas (seller/admin) | Visualização de entregas agrupadas por rota |

---

## 3. Sistema de Zonas de Entrega

### 3.1 Conceito

Em vez de calcular frete por distância exata (que exige geocoding em tempo real e é imprevisível pro cliente), usamos um **sistema de zonas baseado em CEP prefix + cidade**. Cada zona tem preço fixo, prazo estimado, e disponibilidade de tiers (same-day, next-day, standard).

O cliente vê o preço antes de finalizar. Simples, previsível, justo.

### 3.2 Definição das Zonas

```
┌──────────────────────────────────────────────────────────────┐
│ ZONA 0 — "Concórdia Centro"                                 │
│ CEPs: 89700-000 a 89709-999                                 │
│ Raio: 0-5km do centro                                       │
│ Tiers: same-day ✅ | next-day ✅ | agendado ✅              │
│ Frete base: R$6,90                                          │
│ Frete grátis acima de: R$80,00                              │
│ Prazo same-day: até 4h (pedidos antes das 14h)              │
│ Prazo next-day: manhã seguinte                              │
│ Volume máximo entregador: moto (até 10kg / 40x30x30cm)     │
│ Volume máximo van: até 30kg / sem limite prático            │
├──────────────────────────────────────────────────────────────┤
│ ZONA 1 — "Lindóia do Sul"                                   │
│ CEPs: 89735-000 a 89735-999                                 │
│ Distância: ~20km                                            │
│ Tiers: same-day ❌ | next-day ✅ | agendado ✅              │
│ Frete base: R$11,90                                         │
│ Frete grátis acima de: R$120,00                             │
│ Prazo next-day: manhã seguinte                              │
├──────────────────────────────────────────────────────────────┤
│ ZONA 2 — "Peritiba"                                         │
│ CEPs: 89660-000 a 89660-999                                 │
│ Distância: ~22km                                            │
│ Tiers: same-day ❌ | next-day ✅ | agendado ✅              │
│ Frete base: R$12,90                                         │
│ Frete grátis acima de: R$120,00                             │
│ Prazo next-day: manhã seguinte                              │
├──────────────────────────────────────────────────────────────┤
│ ZONA 3 — "Seara"                                            │
│ CEPs: 89770-000 a 89770-999                                 │
│ Distância: ~25km                                            │
│ Tiers: same-day ❌ | next-day ✅ | agendado ✅              │
│ Frete base: R$13,90                                         │
│ Frete grátis acima de: R$130,00                             │
│ Prazo next-day: até 24h                                     │
├──────────────────────────────────────────────────────────────┤
│ ZONA 4 — "Ipumirim"                                         │
│ CEPs: 89790-000 a 89790-999                                 │
│ Distância: ~35km                                            │
│ Tiers: same-day ❌ | next-day ✅ | agendado ✅              │
│ Frete base: R$16,90                                         │
│ Frete grátis acima de: R$150,00                             │
│ Prazo next-day: até 24h                                     │
├──────────────────────────────────────────────────────────────┤
│ ZONA 5 — "Itá"                                              │
│ CEPs: 89760-000 a 89760-999                                 │
│ Distância: ~40km                                            │
│ Tiers: same-day ❌ | next-day ❌ | agendado ✅ (2-3 dias)  │
│ Frete base: R$19,90                                         │
│ Frete grátis acima de: R$180,00                             │
│ Prazo agendado: próxima rota disponível (2-3x/semana)       │
├──────────────────────────────────────────────────────────────┤
│ ZONA 6 — "Piratuba"                                         │
│ CEPs: 89667-000 a 89667-999                                 │
│ Distância: ~45km                                            │
│ Tiers: same-day ❌ | next-day ❌ | agendado ✅ (2-3 dias)  │
│ Frete base: R$19,90                                         │
│ Frete grátis acima de: R$180,00                             │
│ Prazo agendado: próxima rota disponível (2-3x/semana)       │
├──────────────────────────────────────────────────────────────┤
│ ZONA 7 — "Capinzal / Ouro"                                  │
│ CEPs: 89665-000 a 89665-999 (Capinzal), 89663-xxx (Ouro)   │
│ Distância: ~55km                                            │
│ Tiers: same-day ❌ | next-day ❌ | agendado ✅ (3-5 dias)  │
│ Frete base: R$22,90                                         │
│ Frete grátis acima de: R$200,00                             │
│ Prazo agendado: próxima rota disponível (1-2x/semana)       │
└──────────────────────────────────────────────────────────────┘
```

### 3.3 Pontos de Retirada (tier especial)

Cada zona pode ter 0-N pontos de retirada. Quando o comprador escolhe retirar num ponto:
- **Frete reduzido** (50% do frete base da zona) ou **grátis** (dependendo da política)
- **Prazo:** alinhado com a próxima rota de entrega para aquela zona
- **O motoboy entrega no ponto** em vez de ir ao endereço final

Exemplo: ponto de retirada "Farmácia São João" em Seara → motoboy entrega lá todos os pacotes de Seara de uma vez. Cliente retira quando quiser.

### 3.4 Regra de Zona do Vendedor

Cada vendedor opera a partir de um endereço fixo (o `tenant.address`). A zona de entrega é calculada **a partir do endereço do vendedor**, não de Concórdia centro.

Cenário: vendedor em Seara, comprador em Concórdia.
- A distância Seara→Concórdia é ~25km → **Zona 3** (mesma que Concórdia→Seara).
- O cálculo é simétrico: o que importa é a distância entre vendedor e comprador.

**Mas na Fase 1**, como quase todos os vendedores estarão em Concórdia, as zonas definidas acima servem diretamente. Quando um vendedor de outra cidade entrar, a zona do comprador é recalculada relativamente.

### 3.5 Resolução de Zona

A resolução de qual zona um endereço pertence segue esta hierarquia:

```
1. CEP prefix match (89700 → Zona 0, 89770 → Zona 3, etc.)
2. Se CEP não bate com nenhuma zona → cidade match (case-insensitive)
3. Se nem CEP nem cidade batem → coordenadas + distância euclidiana até o vendedor
4. Se distância > 60km → "Fora da área de entrega"
```

A resolução 1 (CEP) cobre 95% dos casos. A resolução 3 (coordenadas) é fallback para endereços rurais com CEP genérico.

---

## 4. Algoritmo de Precificação de Frete

### 4.1 Fórmula Principal

```
frete_final = max(0, frete_base_zona
              + ajuste_peso
              + ajuste_volume
              + premium_tier
              - desconto_frete_gratis)
```

Onde:

```
frete_base_zona     = zona.basePrice (definido na tabela de zonas)
ajuste_peso         = max(0, (peso_total_kg - 5)) × 2.00   [R$2/kg excedente acima de 5kg]
ajuste_volume       = se excede dimensão moto (40x30x30cm) → +R$5,00 (usa van)
premium_tier        = se same-day → +R$4,00 | se next-day → +R$0,00
desconto_frete_gratis = se subtotal >= zona.freeDeliveryMinimum → frete_base_zona (anula o base, mantém ajustes)
```

### 4.2 Exemplos Práticos

**Exemplo 1: Camiseta (200g) entregue em Concórdia, pedido R$50**
```
frete_base_zona = R$6,90 (Zona 0)
ajuste_peso     = max(0, (0.2 - 5)) × 2.00 = R$0,00
ajuste_volume   = cabe na moto → R$0,00
premium_tier    = next-day → R$0,00
desconto        = R$50 < R$80 → R$0,00
────────────────
FRETE FINAL     = R$6,90
```

**Exemplo 2: Camiseta (200g) entregue em Concórdia, pedido R$95, same-day**
```
frete_base_zona = R$6,90 (Zona 0)
ajuste_peso     = R$0,00
ajuste_volume   = R$0,00
premium_tier    = same-day → +R$4,00
desconto        = R$95 >= R$80 → -R$6,90 (anula base)
────────────────
FRETE FINAL     = R$0,00 + R$4,00 = R$4,00
(frete grátis anulou o base, mas premium same-day permanece)
```

**Exemplo 3: Mesa de escritório (12kg, 120x60x75cm) entregue em Seara**
```
frete_base_zona = R$13,90 (Zona 3)
ajuste_peso     = max(0, (12 - 5)) × 2.00 = R$14,00
ajuste_volume   = excede moto (usa van) → +R$5,00
premium_tier    = next-day → R$0,00
desconto        = subtotal < R$130 → R$0,00
────────────────
FRETE FINAL     = R$32,90
```

**Exemplo 4: 3 produtos no carrinho, vendedor em Concórdia, comprador em Ipumirim, retirada em ponto**
```
frete_base_zona = R$16,90 (Zona 4) × 50% (desconto ponto de retirada) = R$8,45
ajuste_peso     = peso total 2kg → R$0,00
ajuste_volume   = cabe na moto → R$0,00
premium_tier    = agendado → R$0,00
desconto        = subtotal < R$150 → R$0,00
────────────────
FRETE FINAL     = R$8,45
```

### 4.3 Regras de Negócio

1. **Frete grátis anula apenas o `frete_base_zona`**, não os ajustes de peso/volume nem premium. Isso evita que frete grátis subsidie entregas de itens pesados ou express.

2. **Peso do pedido = soma dos pesos dos itens × quantidade**. Se algum produto não tiver peso cadastrado, assume 0.5kg por unidade como padrão.

3. **Volume para decisão moto/van**: se QUALQUER item excede 40x30x30cm OU peso total > 10kg → van. Motivo: segurança e praticidade do motoboy.

4. **Same-day só disponível na Zona 0** (Concórdia), pedidos feitos antes das 14h em dia útil. Fora do horário, degrada automaticamente para next-day.

5. **Pedido multi-vendedor**: cada vendedor despacha separadamente. O frete é calculado e cobrado por vendedor (como no Mercado Livre). Na prática, com marketplace regional, a maioria dos pedidos será de um único vendedor.

6. **Frete mínimo**: R$0,00 (pode ser grátis com a regra de freeDeliveryMinimum). Não há frete negativo.

7. **Ajuste sazonal/temporário**: campo `priceMultiplier` na zona permite ajustar todos os preços em X% (ex: 1.2 = +20% em período de alta demanda). Default: 1.0.

### 4.4 Validação Server-Side

**Crítico**: o frete DEVE ser recalculado no backend antes de criar o pedido (assim como os preços dos produtos já são validados). O cliente envia a `deliveryZoneId` e o `deliveryTier` escolhidos, e o backend recalcula o valor. Se houver divergência > R$0,01 com o valor exibido no app, rejeita o pedido.

Isso previne manipulação: um atacante não pode alterar o frete para R$0 via interceptação da requisição.

### 4.5 Pseudocódigo do Cálculo (Backend)

```typescript
interface FreightCalculationInput {
  sellerAddress: AddressModel;      // Endereço do vendedor (tenant)
  buyerAddress: AddressModel;       // Endereço do comprador
  items: OrderItem[];               // Itens do pedido
  deliveryTier: 'same_day' | 'next_day' | 'scheduled' | 'pickup_point';
  pickupPointId?: string;           // Se tier = pickup_point
}

interface FreightCalculationResult {
  zoneId: string;
  zoneName: string;
  basePrice: number;
  weightSurcharge: number;
  volumeSurcharge: number;
  tierPremium: number;
  freeDeliveryDiscount: number;
  pickupDiscount: number;
  finalPrice: number;
  estimatedDelivery: string;         // "Hoje até 18h" | "Amanhã" | "Em 2-3 dias"
  estimatedDeliveryDate: Date;
  requiresVan: boolean;
  available: boolean;                // false se zona não atende esse tier
  unavailableReason?: string;        // "Same-day indisponível para esta zona"
}

function calculateFreight(input: FreightCalculationInput): FreightCalculationResult {
  // 1. Resolver zona
  const zone = resolveZone(input.sellerAddress, input.buyerAddress);
  if (!zone) {
    return { available: false, unavailableReason: "Endereço fora da área de entrega" };
  }

  // 2. Verificar disponibilidade do tier na zona
  if (input.deliveryTier === 'same_day' && !zone.sameDayAvailable) {
    return { available: false, unavailableReason: "Entrega no mesmo dia não disponível para esta região" };
  }
  if (input.deliveryTier === 'same_day' && isPastCutoff()) {
    return { available: false, unavailableReason: "Pedidos same-day aceitos até 14h" };
  }
  if (input.deliveryTier === 'next_day' && !zone.nextDayAvailable) {
    return { available: false, unavailableReason: "Entrega no dia seguinte não disponível para esta região" };
  }

  // 3. Calcular peso e volume
  const totalWeight = input.items.reduce((sum, item) => {
    const itemWeight = item.weight ?? 0.5; // default 500g
    return sum + (itemWeight * item.quantity);
  }, 0);

  const requiresVan = totalWeight > 10 || input.items.some(item =>
    item.width > 40 || item.height > 30 || item.length > 30
  );

  // 4. Calcular componentes
  const basePrice = zone.basePrice * (zone.priceMultiplier ?? 1.0);
  const weightSurcharge = Math.max(0, (totalWeight - 5)) * 2.00;
  const volumeSurcharge = requiresVan ? 5.00 : 0;

  let tierPremium = 0;
  if (input.deliveryTier === 'same_day') tierPremium = 4.00;

  // 5. Frete grátis
  const subtotal = input.items.reduce((s, i) => s + i.total, 0);
  const freeDeliveryDiscount = subtotal >= zone.freeDeliveryMinimum ? basePrice : 0;

  // 6. Desconto ponto de retirada
  let pickupDiscount = 0;
  if (input.deliveryTier === 'pickup_point') {
    pickupDiscount = basePrice * 0.5; // 50% do base
  }

  // 7. Preço final
  const finalPrice = Math.max(0,
    basePrice
    + weightSurcharge
    + volumeSurcharge
    + tierPremium
    - freeDeliveryDiscount
    - pickupDiscount
  );

  // 8. Estimativa de entrega
  const estimatedDelivery = calculateEstimatedDelivery(zone, input.deliveryTier);

  return {
    zoneId: zone.id,
    zoneName: zone.name,
    basePrice,
    weightSurcharge,
    volumeSurcharge,
    tierPremium,
    freeDeliveryDiscount,
    pickupDiscount,
    finalPrice,
    estimatedDelivery: estimatedDelivery.label,
    estimatedDeliveryDate: estimatedDelivery.date,
    requiresVan,
    available: true,
  };
}
```

### 4.6 Estimativa de Prazo de Entrega

```typescript
function calculateEstimatedDelivery(
  zone: DeliveryZone,
  tier: string
): { label: string; date: Date } {
  const now = new Date();
  const hour = now.getHours();
  const isWeekday = now.getDay() >= 1 && now.getDay() <= 5;
  const isSaturday = now.getDay() === 6;

  if (tier === 'same_day') {
    // Só Zona 0, antes das 14h, dia útil
    return { label: "Hoje até 18h", date: todayAt(18, 0) };
  }

  if (tier === 'next_day') {
    if (isWeekday && hour < 18) {
      // Pedido feito em dia útil antes das 18h → amanhã
      const tomorrow = addDays(now, 1);
      if (tomorrow.getDay() === 0) {
        // Amanhã é domingo → segunda
        return { label: "Segunda-feira", date: addDays(now, 2) };
      }
      return { label: "Amanhã", date: tomorrow };
    }
    if (isSaturday && hour < 12) {
      // Sábado antes do meio-dia → segunda
      return { label: "Segunda-feira", date: nextMonday(now) };
    }
    // Fora do horário → próximo dia útil + 1
    return { label: "Em até 2 dias úteis", date: addBusinessDays(now, 2) };
  }

  if (tier === 'scheduled') {
    // Zonas distantes — baseado na frequência de rota
    const daysUntilRoute = zone.routeFrequencyDays ?? 3;
    const deliveryDate = addBusinessDays(now, daysUntilRoute);
    if (daysUntilRoute <= 2) return { label: "Em até 2 dias úteis", date: deliveryDate };
    if (daysUntilRoute <= 3) return { label: "Em 2-3 dias úteis", date: deliveryDate };
    return { label: `Em até ${daysUntilRoute} dias úteis`, date: deliveryDate };
  }

  if (tier === 'pickup_point') {
    // Mesma lógica do scheduled, mas pode ser mais rápido se na mesma rota
    const daysUntilRoute = Math.max(1, (zone.routeFrequencyDays ?? 2) - 1);
    const deliveryDate = addBusinessDays(now, daysUntilRoute);
    return { label: `Disponível para retirada em ${daysUntilRoute} dia(s) útil(eis)`, date: deliveryDate };
  }

  return { label: "Consultar prazo", date: addDays(now, 7) };
}
```

---

## 5. Algoritmo de Prioridade e Roteirização

### 5.1 Problema

Com 5-15 pedidos/dia e 2-3 motoboys, não é viável despachar cada pedido individualmente. A estratégia é **agrupar pedidos em rotas** e **priorizar quais rotas saem primeiro**.

### 5.2 Janelas de Despacho

```
┌─────────────────────────────────────────────────────────┐
│ JANELA DA MANHÃ (08h-12h)                               │
│                                                         │
│ Cutoff: 08h                                             │
│ Inclui:                                                 │
│   - Pedidos same-day recebidos até agora                │
│   - Pedidos next-day do dia anterior                    │
│   - Pedidos agendados cuja rota é hoje                  │
│                                                         │
│ Despacho: ~09h (após vendedores prepararem)             │
├─────────────────────────────────────────────────────────┤
│ JANELA DA TARDE (12h-18h)                               │
│                                                         │
│ Cutoff: 14h                                             │
│   - Pedidos same-day recebidos entre 08h-14h            │
│   - Pedidos next-day que entraram de manhã              │
│   - Remanescentes da manhã (vendedor atrasou)           │
│                                                         │
│ Despacho: ~14h30                                        │
├─────────────────────────────────────────────────────────┤
│ SÁBADO (08h-12h)                                        │
│                                                         │
│ Cutoff: 08h (sexta 18h na prática)                      │
│   - Pedidos acumulados de sexta à noite                 │
│   - Same-day NÃO disponível no sábado                  │
│   - Apenas Zona 0 e Zona 1 (prioridade próxima)        │
│                                                         │
│ Despacho: ~09h                                          │
└─────────────────────────────────────────────────────────┘
```

### 5.3 Score de Prioridade (por pedido)

Cada pedido recebe um score numérico. Pedidos com score maior são despachados primeiro.

```typescript
function calculatePriorityScore(order: OrderWithDelivery): number {
  let score = 0;

  // ═══ FATOR 1: Tipo de produto (0-100 pontos) ═══
  if (order.hasPerishableItems) score += 100;
  // Perecíveis SEMPRE são prioridade máxima — não podem esperar

  // ═══ FATOR 2: Tier de entrega (0-80 pontos) ═══
  switch (order.deliveryTier) {
    case 'same_day':  score += 80; break;  // Cliente pagou premium, expectativa alta
    case 'next_day':  score += 50; break;  // Compromisso de 24h
    case 'scheduled': score += 20; break;  // Mais flexível
    case 'pickup_point': score += 15; break; // Sem urgência — ponto armazena
  }

  // ═══ FATOR 3: Idade do pedido (0-60 pontos) ═══
  // Pedidos mais velhos ganham prioridade progressiva para evitar "starvation"
  const hoursWaiting = (Date.now() - order.sellerReadyAt.getTime()) / 3600000;
  // sellerReadyAt = momento em que vendedor marcou "pronto para coleta"
  score += Math.min(Math.floor(hoursWaiting * 8), 60);
  // +8 pts/hora, cap em 60 (atinge máximo em ~7.5h)
  // Pedido de ontem à tarde que ainda não saiu: +60 pontos

  // ═══ FATOR 4: Valor do pedido (0-20 pontos) ═══
  // Pedidos de valor alto têm prioridade marginal (mais receita em risco)
  if (order.total >= 200) score += 20;
  else if (order.total >= 100) score += 10;
  else if (order.total >= 50) score += 5;

  // ═══ FATOR 5: Recorrência do comprador (0-15 pontos) ═══
  // Compradores recorrentes merecem tratamento premium (retenção)
  if (order.buyerOrderCount >= 10) score += 15;
  else if (order.buyerOrderCount >= 5) score += 10;
  else if (order.buyerOrderCount >= 2) score += 5;

  return score;
}
```

### 5.4 Agrupamento em Rotas

Após calcular o score de cada pedido, o sistema agrupa pedidos em rotas otimizadas:

```typescript
interface DeliveryRoute {
  id: string;
  dispatchWindow: 'morning' | 'afternoon';
  date: Date;
  zone: DeliveryZone;                // Rota por zona (simplifica)
  orders: OrderWithDelivery[];       // Pedidos nesta rota, ordenados por prioridade
  assignedDriver?: string;           // ID do entregador
  vehicleType: 'motorcycle' | 'van'; // Baseado nos itens
  status: 'pending' | 'dispatched' | 'in_progress' | 'completed';
  estimatedDuration: number;          // Minutos
  totalStops: number;
  totalPackages: number;
}

function buildRoutes(
  pendingOrders: OrderWithDelivery[],
  dispatchWindow: 'morning' | 'afternoon'
): DeliveryRoute[] {
  // 1. Filtrar pedidos elegíveis para esta janela
  const eligible = pendingOrders.filter(order => {
    if (order.deliveryTier === 'same_day') return true;
    if (order.deliveryTier === 'next_day') return isOrderReady(order);
    if (order.deliveryTier === 'scheduled') return isRouteDay(order.zone);
    if (order.deliveryTier === 'pickup_point') return isRouteDay(order.zone);
    return false;
  });

  // 2. Agrupar por zona
  const byZone = groupBy(eligible, order => order.zoneId);

  // 3. Para cada zona, criar rota(s)
  const routes: DeliveryRoute[] = [];

  for (const [zoneId, zoneOrders] of Object.entries(byZone)) {
    // Ordenar por priority score (descending)
    const sorted = zoneOrders.sort((a, b) => b.priorityScore - a.priorityScore);

    // Separar moto vs van
    const vanOrders = sorted.filter(o => o.requiresVan);
    const motoOrders = sorted.filter(o => !o.requiresVan);

    // Rota(s) de moto — máximo 8 paradas por rota (capacidade do baú)
    for (let i = 0; i < motoOrders.length; i += 8) {
      const batch = motoOrders.slice(i, i + 8);
      routes.push(createRoute(batch, 'motorcycle', dispatchWindow, zoneId));
    }

    // Rota de van — máximo 12 paradas (ou limite de peso)
    for (let i = 0; i < vanOrders.length; i += 12) {
      const batch = vanOrders.slice(i, i + 12);
      routes.push(createRoute(batch, 'van', dispatchWindow, zoneId));
    }
  }

  // 4. Ordenar rotas por prioridade média (zona com pedidos mais urgentes primeiro)
  routes.sort((a, b) => {
    const avgA = a.orders.reduce((s, o) => s + o.priorityScore, 0) / a.orders.length;
    const avgB = b.orders.reduce((s, o) => s + o.priorityScore, 0) / b.orders.length;
    return avgB - avgA;
  });

  return routes;
}
```

### 5.5 Regras de Rota

1. **Uma rota = uma zona = um veículo.** Não misturar zonas numa rota (evita desvios longos).

2. **Exceção:** zonas adjacentes com poucos pedidos podem ser combinadas. Ex: Zona 5 (Itá) + Zona 6 (Piratuba) na mesma rota se houver 1-2 pedidos em cada. A decisão é manual (operador) na Fase 1, automática na Fase 2.

3. **Limite de paradas por rota:**
   - Moto: 8 paradas (capacidade do baú + tempo)
   - Van: 12 paradas
   - Se exceder, cria rota adicional

4. **Moto vs Van:** decidido pelo pedido mais volumoso/pesado da rota. Se UM pedido precisa de van, a rota inteira vai de van. Os pedidos de moto daquela zona vão na mesma van (mais eficiente).

5. **Pedido do tipo pickup_point:** o endereço de entrega é o do ponto, não o do comprador. Múltiplos pedidos pro mesmo ponto = 1 parada só.

6. **Vendedor precisa marcar "pronto para coleta"** antes do pedido entrar numa rota. Pedido sem marcação de vendedor fica em "aguardando vendedor" e não entra no agrupamento.

### 5.6 Ordenação Interna da Rota (sequência de paradas)

Dentro de uma rota, a ordem das paradas segue:

```
1. Pontos de retirada primeiro (1 parada resolve N pedidos)
2. Depois endereços individuais, ordenados por:
   a. Priority score (maior primeiro)
   b. Se scores iguais: proximidade geográfica (nearest-neighbor heuristic)
```

Na Fase 1, esta ordenação é sugestiva (o motoboy vê a lista mas pode reordenar). Na Fase 2, integra com API de roteirização (Google Directions / RoutEasy).

### 5.7 Fluxo Visual do Algoritmo

```
                    ┌──────────────────┐
                    │ Pedidos pendentes │
                    │  (seller ready)   │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Calcular priority │
                    │  score por pedido │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Filtrar por janela│
                    │ (manhã ou tarde)  │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Agrupar por zona  │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
        │  Zona 0   │ │  Zona 3   │ │  Zona 5+6 │
        │ Concórdia │ │   Seara   │ │  Itá+Pira │
        └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
              │              │              │
        ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
        │ Separar   │ │ Separar   │ │ Separar   │
        │ moto/van  │ │ moto/van  │ │ moto/van  │
        └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
              │              │              │
        ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
        │ Criar     │ │ Criar     │ │ Criar     │
        │ rota(s)   │ │ rota(s)   │ │ rota(s)   │
        └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼─────────┐
                    │ Ordenar rotas por│
                    │ prioridade média │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Atribuir driver  │
                    │  (manual Fase 1) │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │    DESPACHAR      │
                    └──────────────────┘
```

---

## 6. Modelo de Dados — Novas Coleções e Campos

### 6.1 Nova Coleção: `delivery_zones`

```typescript
// Firestore: delivery_zones/{zoneId}
interface DeliveryZone {
  id: string;                         // Ex: "zone_concordia"
  name: string;                       // Ex: "Concórdia"
  description: string;                // Ex: "Centro e bairros de Concórdia"

  // Resolução de zona
  cepPrefixes: string[];              // Ex: ["89700", "89701", "89702", ...]
  cities: string[];                   // Ex: ["Concórdia"] (fallback se CEP não bater)
  maxRadiusKm: number;               // Ex: 5 (para fallback por coordenadas)
  centerCoordinates: {                // Centro geográfico da zona
    latitude: number;
    longitude: number;
  };

  // Precificação
  basePrice: number;                  // R$ base para esta zona
  freeDeliveryMinimum: number;        // Subtotal mínimo para frete grátis (base)
  priceMultiplier: number;            // Default 1.0 — sazonal/temporário

  // Tiers disponíveis
  sameDayAvailable: boolean;
  sameDayCutoffHour: number;          // Ex: 14 (14h)
  nextDayAvailable: boolean;
  scheduledAvailable: boolean;

  // Frequência de rota (para zonas agendadas)
  routeFrequencyDays: number;         // A cada N dias úteis tem rota
  routeDays?: string[];               // Dias fixos: ["monday", "wednesday", "friday"]

  // Limites
  maxWeightKg: number;                // Peso máximo aceito nesta zona

  // Metadata
  sortOrder: number;                  // Para ordenação na UI
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 6.2 Nova Coleção: `pickup_points`

```typescript
// Firestore: pickup_points/{pointId}
interface PickupPoint {
  id: string;
  name: string;                       // Ex: "Farmácia São João — Centro"
  type: string;                       // "pharmacy" | "market" | "gas_station" | "store" | "other"

  // Localização
  address: AddressModel;              // Endereço completo com coordinates
  zoneId: string;                     // Referência à delivery_zone

  // Horários de funcionamento (para informar o comprador)
  businessHours: {
    [day: string]: {                  // "monday", "tuesday", etc.
      open: string;                   // "08:00"
      close: string;                  // "18:00"
    } | null;                         // null = fechado neste dia
  };

  // Política
  maxHoldDays: number;                // Dias que o ponto segura o pacote (ex: 5)
  maxPackages: number;                // Capacidade simultânea (ex: 20)
  currentPackages: number;            // Pacotes atualmente no ponto

  // Contato
  phone: string;
  contactName: string;                // Responsável

  // Financeiro
  commissionPerPackage: number;       // R$ pago ao ponto por pacote (ex: 2.00)

  // Status
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 6.3 Nova Coleção: `delivery_routes`

```typescript
// Firestore: delivery_routes/{routeId}
interface DeliveryRoute {
  id: string;
  date: Timestamp;                    // Data da rota
  dispatchWindow: 'morning' | 'afternoon';
  zoneId: string;                     // Zona principal
  zoneName: string;                   // Desnormalizado para display

  // Veículo e motorista
  vehicleType: 'motorcycle' | 'van';
  driverId?: string;                  // userId do entregador (quando atribuído)
  driverName?: string;                // Desnormalizado

  // Paradas
  stops: DeliveryStop[];              // Ordenadas por sequência
  totalStops: number;
  totalPackages: number;

  // Status
  status: 'pending' | 'dispatched' | 'in_progress' | 'completed' | 'cancelled';
  dispatchedAt?: Timestamp;
  completedAt?: Timestamp;

  // Métricas
  estimatedDurationMinutes: number;
  actualDurationMinutes?: number;

  createdAt: Timestamp;
  updatedAt: Timestamp;
}

interface DeliveryStop {
  sequence: number;                   // Ordem na rota (1, 2, 3...)
  orderId: string;
  orderNumber: string;                // Desnormalizado (RDB-XXX)

  // Destino
  type: 'address' | 'pickup_point';
  address: AddressModel;              // Endereço de entrega ou do ponto
  pickupPointId?: string;             // Se type = pickup_point
  pickupPointName?: string;           // Desnormalizado

  // Coleta (onde buscar o pacote)
  sellerAddress: AddressModel;        // Endereço do vendedor
  sellerName: string;
  sellerId: string;                   // tenantId

  // Pacote
  items: { name: string; quantity: number }[];
  totalWeight: number;
  requiresVan: boolean;

  // Prioridade
  priorityScore: number;
  deliveryTier: string;

  // Status individual
  status: 'pending' | 'collected' | 'delivered' | 'failed';
  collectedAt?: Timestamp;            // Quando coletou do vendedor
  deliveredAt?: Timestamp;            // Quando entregou ao comprador
  failureReason?: string;             // "Destinatário ausente", etc.

  // Buyer info (para o entregador)
  buyerName: string;
  buyerPhone?: string;
}
```

### 6.4 Alterações no `OrderModel` (campos novos)

```dart
// Novos campos a adicionar em order_model.dart
class OrderModel {
  // ... campos existentes ...

  // ═══ NOVOS CAMPOS DE ENTREGA ═══
  final String? deliveryZoneId;         // ID da zona de entrega
  final String? deliveryZoneName;       // Nome da zona (desnormalizado)
  final String deliveryTier;            // 'same_day' | 'next_day' | 'scheduled' | 'pickup_point'
  final String? pickupPointId;          // Se tier = pickup_point
  final String? pickupPointName;        // Nome do ponto (desnormalizado)
  final String? deliveryRouteId;        // Rota atribuída (preenchido pelo sistema)
  final DateTime? sellerReadyAt;        // Quando vendedor marcou "pronto para coleta"
  final DateTime? collectedAt;          // Quando motoboy coletou do vendedor
  final DateTime? estimatedDeliveryDate; // Data estimada (calculada pelo algoritmo)

  // ═══ BREAKDOWN DO FRETE ═══
  final DeliveryFeeBreakdown? deliveryFeeBreakdown;
}

class DeliveryFeeBreakdown {
  final double basePrice;               // Preço base da zona
  final double weightSurcharge;         // Adicional de peso
  final double volumeSurcharge;         // Adicional de volume (van)
  final double tierPremium;             // Premium same-day
  final double freeDeliveryDiscount;    // Desconto frete grátis
  final double pickupDiscount;          // Desconto ponto de retirada
  final double finalPrice;              // = deliveryFee no order
}
```

### 6.5 Alterações no `ProductModel` (campos novos)

```dart
// Novos campos a adicionar em product_model.dart
class ProductModel {
  // ... campos existentes ...

  // ═══ NOVOS CAMPOS DE ENVIO ═══
  final double? weight;                 // Peso em kg (ex: 0.5)
  final ProductDimensions? dimensions;  // Dimensões para cálculo moto/van
  final bool isPerishable;              // Perecível? (prioridade máxima)
  final String? shippingCategory;       // 'standard' | 'fragile' | 'bulky' | 'perishable'
}

class ProductDimensions {
  final double width;                   // cm
  final double height;                  // cm
  final double length;                  // cm
}
```

### 6.6 Alterações no `TenantModel`

```dart
// Mudar campo address de String? para AddressModel?
class TenantModel {
  // ... campos existentes ...

  // ANTES: final String? address;
  // DEPOIS:
  final AddressModel? address;          // Endereço completo com coordinates
  // (necessário para cálculo de distância vendedor→comprador)
}
```

### 6.7 Alterações no `CheckoutState`

```dart
class CheckoutState {
  // ... campos existentes ...

  // ═══ NOVO STEP DE ENTREGA ═══
  // Step order: address → delivery → payment → cardDetails → review → processing → complete

  final List<FreightOption>? freightOptions;    // Opções retornadas pelo backend
  final FreightOption? selectedFreightOption;   // Opção escolhida pelo comprador
}

class FreightOption {
  final String zoneId;
  final String zoneName;
  final String tier;                    // 'same_day' | 'next_day' | 'scheduled' | 'pickup_point'
  final String tierLabel;               // "Hoje até 18h" | "Amanhã" | "Em 2-3 dias"
  final double price;                   // Preço final
  final String estimatedDelivery;       // Label legível
  final DateTime estimatedDeliveryDate;
  final bool requiresVan;
  final String? pickupPointId;          // Se tier = pickup_point
  final String? pickupPointName;
  final String? pickupPointAddress;     // Endereço resumido do ponto

  // Breakdown (para exibir detalhes)
  final double basePrice;
  final double weightSurcharge;
  final double volumeSurcharge;
  final double tierPremium;
  final double freeDeliveryDiscount;
  final double pickupDiscount;
}
```

---

## 7. Backend — Novos Endpoints

### 7.1 Novo Router: `functions/src/routes/shipping.ts`

```
POST   /api/shipping/calculate          — Calcular opções de frete
GET    /api/shipping/zones              — Listar zonas ativas (público)
GET    /api/shipping/zones/:id          — Detalhes de uma zona
GET    /api/shipping/pickup-points      — Listar pontos de retirada (público, filtro por zona)
GET    /api/shipping/pickup-points/:id  — Detalhes de um ponto
```

### 7.2 Detalhamento dos Endpoints

#### `POST /api/shipping/calculate`

**Autenticação:** Requer auth (precisa do endereço do comprador)

**Request:**
```json
{
  "tenantId": "seller-tenant-id",
  "addressId": "buyer-address-id",
  "items": [
    {
      "productId": "prod-1",
      "variantId": "var-1",
      "quantity": 2
    }
  ]
}
```

**Response (200):**
```json
{
  "options": [
    {
      "zoneId": "zone_concordia",
      "zoneName": "Concórdia",
      "tier": "same_day",
      "tierLabel": "Entrega Hoje",
      "price": 10.90,
      "estimatedDelivery": "Hoje até 18h",
      "estimatedDeliveryDate": "2026-02-28T18:00:00Z",
      "requiresVan": false,
      "pickupPointId": null,
      "pickupPointName": null,
      "pickupPointAddress": null,
      "breakdown": {
        "basePrice": 6.90,
        "weightSurcharge": 0,
        "volumeSurcharge": 0,
        "tierPremium": 4.00,
        "freeDeliveryDiscount": 0,
        "pickupDiscount": 0
      }
    },
    {
      "zoneId": "zone_concordia",
      "zoneName": "Concórdia",
      "tier": "next_day",
      "tierLabel": "Entrega Amanhã",
      "price": 6.90,
      "estimatedDelivery": "Amanhã",
      "estimatedDeliveryDate": "2026-03-01T12:00:00Z",
      "requiresVan": false,
      "pickupPointId": null,
      "pickupPointName": null,
      "pickupPointAddress": null,
      "breakdown": {
        "basePrice": 6.90,
        "weightSurcharge": 0,
        "volumeSurcharge": 0,
        "tierPremium": 0,
        "freeDeliveryDiscount": 0,
        "pickupDiscount": 0
      }
    },
    {
      "zoneId": "zone_concordia",
      "zoneName": "Concórdia",
      "tier": "pickup_point",
      "tierLabel": "Retirar na Farmácia São João",
      "price": 3.45,
      "estimatedDelivery": "Disponível amanhã",
      "estimatedDeliveryDate": "2026-03-01T10:00:00Z",
      "requiresVan": false,
      "pickupPointId": "pp_farmacia_sao_joao",
      "pickupPointName": "Farmácia São João — Centro",
      "pickupPointAddress": "Rua Marechal Deodoro, 500",
      "breakdown": {
        "basePrice": 6.90,
        "weightSurcharge": 0,
        "volumeSurcharge": 0,
        "tierPremium": 0,
        "freeDeliveryDiscount": 0,
        "pickupDiscount": 3.45
      }
    }
  ],
  "freeDeliveryMessage": "Adicione mais R$30,10 para frete grátis!"
}
```

**Response (400) — fora da área:**
```json
{
  "error": "OUT_OF_DELIVERY_AREA",
  "message": "Infelizmente ainda não entregamos nesta região. Atendemos Concórdia e cidades próximas."
}
```

**Lógica interna:**
1. Buscar endereço do comprador (`users/{uid}/addresses/{addressId}`)
2. Buscar endereço do vendedor (`tenants/{tenantId}.address`)
3. Buscar produtos para obter peso e dimensões
4. Resolver zona (CEP prefix → cidade → coordenadas)
5. Se zona não encontrada → retornar erro `OUT_OF_DELIVERY_AREA`
6. Calcular preço para cada tier disponível na zona
7. Buscar pontos de retirada na zona → calcular opção de pickup
8. Retornar todas as opções ordenadas (same_day > next_day > scheduled > pickup_point)
9. Calcular `freeDeliveryMessage` se subtotal < freeDeliveryMinimum

#### `GET /api/shipping/zones`

**Autenticação:** Público (exibir no app para informar áreas de entrega)

**Response (200):**
```json
{
  "zones": [
    {
      "id": "zone_concordia",
      "name": "Concórdia",
      "description": "Centro e bairros",
      "basePrice": 6.90,
      "freeDeliveryMinimum": 80.00,
      "sameDayAvailable": true,
      "nextDayAvailable": true,
      "estimatedDelivery": "Mesmo dia ou dia seguinte"
    },
    {
      "id": "zone_seara",
      "name": "Seara",
      "description": "Seara e região",
      "basePrice": 13.90,
      "freeDeliveryMinimum": 130.00,
      "sameDayAvailable": false,
      "nextDayAvailable": true,
      "estimatedDelivery": "Dia seguinte"
    }
  ]
}
```

#### `GET /api/shipping/pickup-points?zoneId=zone_concordia`

**Autenticação:** Público

**Response (200):**
```json
{
  "points": [
    {
      "id": "pp_farmacia_sao_joao",
      "name": "Farmácia São João — Centro",
      "type": "pharmacy",
      "address": {
        "street": "Rua Marechal Deodoro",
        "number": "500",
        "neighborhood": "Centro",
        "city": "Concórdia",
        "state": "SC"
      },
      "businessHours": {
        "monday": { "open": "08:00", "close": "19:00" },
        "saturday": { "open": "08:00", "close": "12:00" },
        "sunday": null
      },
      "maxHoldDays": 5
    }
  ]
}
```

### 7.3 Alterações em Endpoints Existentes

#### `POST /api/orders` (payments.ts) — Mudanças

**Request adicional:**
```json
{
  "deliveryTier": "next_day",
  "deliveryZoneId": "zone_concordia",
  "pickupPointId": null,
  "deliveryFeeFromClient": 6.90
}
```

**Mudanças na lógica:**

```
1. ANTES: deliveryFee = 0
   DEPOIS: Recalcular frete server-side usando mesma lógica do /api/shipping/calculate

2. VALIDAÇÃO: |deliveryFeeFromClient - deliveryFeeCalculated| <= 0.01
   Se divergir → HttpsError("Valor do frete diverge. Atualize a página.")

3. ANTES: total = subtotal - discount
   DEPOIS: total = subtotal - discount + deliveryFee

4. NOVOS CAMPOS no orderData:
   - deliveryZoneId
   - deliveryZoneName
   - deliveryTier
   - pickupPointId (se aplicável)
   - pickupPointName (se aplicável)
   - deliveryFeeBreakdown: { basePrice, weightSurcharge, volumeSurcharge, ... }
   - estimatedDeliveryDate
   - sellerReadyAt: null (preenchido depois pelo vendedor)
   - collectedAt: null
   - deliveryRouteId: null

5. paymentSplit recalculado:
   - platformFeeAmount = (subtotal - discount) * feePercentage
   - NÃO cobra taxa sobre deliveryFee (frete não é receita do vendedor)
   - sellerAmount = total - platformFeeAmount - deliveryFee

   NOTA: deliveryFee vai para a conta operacional do marketplace (cobre custos de entrega).
   O vendedor NÃO recebe o valor do frete. Apenas o valor dos produtos - taxa da plataforma.
```

#### `PATCH /api/seller/orders/:id/status` — Novo status

Adicionar ação `ready_for_collection`:

```
Quando vendedor marca status = "ready":
  - Gravar sellerReadyAt = now
  - Pedido se torna elegível para entrar na próxima rota
  - Notificação ao comprador: "Seu pedido está sendo preparado para envio"
```

### 7.4 Novo Endpoint: Gestão de Rotas (Admin/Operador)

```
GET    /api/admin/routes?date=2026-02-28&window=morning   — Rotas do dia
POST   /api/admin/routes/generate                          — Gerar rotas para próxima janela
PATCH  /api/admin/routes/:id                               — Atualizar rota (atribuir driver, reordenar)
PATCH  /api/admin/routes/:id/stops/:orderId                — Marcar parada (collected/delivered/failed)
```

Na **Fase 1**, a geração de rotas pode ser semi-manual: o operador clica "Gerar rotas" e o sistema cria as rotas automaticamente, mas o operador pode ajustar (reordenar paradas, mover pedidos entre rotas, atribuir motorista).

---

## 8. Flutter — Novos Providers e Telas

### 8.1 Novo Provider: `shipping_provider.dart`

```dart
// lib/presentation/providers/shipping_provider.dart

/// Calcula opções de frete para o checkout
/// Parâmetros: tenantId, addressId, items do carrinho
/// Retorna: lista de FreightOption
final freightOptionsProvider = FutureProvider.autoDispose
    .family<List<FreightOption>, FreightCalculationParams>((ref, params) async {
  final repo = ref.read(shippingRepositoryProvider);
  return repo.calculateFreight(
    tenantId: params.tenantId,
    addressId: params.addressId,
    items: params.items,
  );
});

/// Opção de frete selecionada pelo comprador
final selectedFreightOptionProvider = StateProvider.autoDispose<FreightOption?>((ref) => null);

/// Lista de zonas de entrega (público, para tela informativa)
final deliveryZonesProvider = FutureProvider<List<DeliveryZone>>((ref) async {
  final repo = ref.read(shippingRepositoryProvider);
  return repo.getZones();
});

/// Pontos de retirada por zona
final pickupPointsProvider = FutureProvider.autoDispose
    .family<List<PickupPoint>, String>((ref, zoneId) async {
  final repo = ref.read(shippingRepositoryProvider);
  return repo.getPickupPoints(zoneId: zoneId);
});
```

### 8.2 Novo Repository: `shipping_repository.dart`

```dart
// lib/domain/repositories/shipping_repository.dart
abstract class ShippingRepository {
  Future<List<FreightOption>> calculateFreight({
    required String tenantId,
    required String addressId,
    required List<CartItem> items,
  });

  Future<List<DeliveryZone>> getZones();

  Future<List<PickupPoint>> getPickupPoints({String? zoneId});
}

// lib/data/repositories/shipping_repository_impl.dart
// Implementa chamadas HTTP aos endpoints de /api/shipping/*
```

### 8.3 Alterações no Checkout Flow

**Novo step no checkout: Delivery (entre Address e Payment)**

```
Step 1: Address (existente)     → Selecionar endereço de entrega
Step 2: Delivery (NOVO)         → Escolher método de entrega + ver frete
Step 3: Payment (existente)     → Escolher forma de pagamento
Step 4: Card Details (existente)
Step 5: Review (existente)      → Agora mostra frete no resumo
Step 6: Processing (existente)
Step 7: Complete (existente)
```

**Enum `CheckoutStep`:**
```dart
enum CheckoutStep {
  address,
  delivery,    // ← NOVO
  payment,
  cardDetails,
  review,
  processing,
  complete,
}
```

### 8.4 UI do Step de Delivery

```
┌─────────────────────────────────────────────┐
│ Escolha a entrega                           │
│                                             │
│ Entregamos em Concórdia e região            │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ⚡ Entrega Hoje        R$10,90         │ │
│ │    Até 18h — Concórdia                  │ │
│ │    (pedidos até 14h)                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🚀 Entrega Amanhã     R$6,90    ← ●   │ │
│ │    Dia seguinte                         │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 📍 Retirar no ponto   R$3,45          │ │
│ │    Farmácia São João — Centro           │ │
│ │    Disponível amanhã                    │ │
│ │    Seg-Sex 08h-19h, Sáb 08h-12h        │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 📦 Entrega Agendada   GRÁTIS          │ │
│ │    Em 2-3 dias úteis                    │ │
│ │    (pedido acima de R$80)               │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Adicione mais R$30 para frete grátis!       │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │           Continuar                      │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Comportamentos:**
- Ao entrar neste step, dispara `POST /api/shipping/calculate` automaticamente
- Mostra shimmer enquanto calcula
- Se endereço fora da área → mostra mensagem de erro com botão para trocar endereço
- Se same-day não disponível (horário/zona) → card fica desabilitado com razão
- Frete grátis: destaca com badge verde e risca o preço original
- Ao selecionar opção → atualiza `cart_summary` com o frete em tempo real

### 8.5 Alterações no `cart_summary.dart`

```
ANTES:
  Subtotal: R$50,00
  "Combinar entrega e pagamento diretamente com o vendedor"

DEPOIS:
  Subtotal:          R$50,00
  Frete (Amanhã):    R$6,90      ← ou "GRÁTIS" se aplicável
  ─────────────────────────
  Total:             R$56,90
```

Se o frete ainda não foi selecionado (step anterior ao delivery), mostra:
```
  Subtotal:          R$50,00
  Frete:             Calcular no próximo passo
  ─────────────────────────
  Total:             R$50,00+
```

### 8.6 Tela Informativa: "Onde entregamos"

Nova tela acessível da home/perfil/FAQ:

```
┌─────────────────────────────────────────────┐
│ ← Onde entregamos                           │
│                                             │
│ Entregamos em Concórdia e cidades           │
│ próximas com nossa frota própria.           │
│                                             │
│ ┌─ Concórdia ─────────────────────────────┐ │
│ │ A partir de R$6,90 | Mesmo dia ou D+1   │ │
│ │ Grátis acima de R$80                     │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─ Seara ─────────────────────────────────┐ │
│ │ A partir de R$13,90 | Dia seguinte      │ │
│ │ Grátis acima de R$130                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─ Ipumirim ──────────────────────────────┐ │
│ │ A partir de R$16,90 | Dia seguinte      │ │
│ │ Grátis acima de R$150                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ... (demais zonas)                          │
│                                             │
│ 📍 Pontos de retirada                      │
│ Retire seu pedido com desconto:             │
│                                             │
│ ┌─ Farmácia São João — Concórdia ─────────┐ │
│ │ Rua Marechal Deodoro, 500               │ │
│ │ Seg-Sex 08h-19h, Sáb 08h-12h           │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Sua cidade não está na lista?               │
│ Estamos expandindo! [Solicitar cobertura]   │
│                                             │
└─────────────────────────────────────────────┘
```

### 8.7 Seller: Marcar "Pronto para Coleta"

No `seller_order_details_screen.dart`, adicionar botão após status `confirmed`/`preparing`:

```
Ao clicar "Pronto para Coleta":
  → PATCH /api/seller/orders/:id/status { status: "ready", note: "Pronto para coleta" }
  → Backend grava sellerReadyAt = now
  → Pedido entra na fila de roteirização
  → Notificação ao comprador: "Seu pedido está pronto e será coletado em breve!"
```

---

## 9. Fluxo Completo do Pedido (Novo)

```
COMPRADOR                          SISTEMA                           VENDEDOR
─────────                          ───────                           ────────

1. Adiciona itens ao carrinho
2. Vai ao checkout
3. Seleciona endereço ──────────→ Calcula frete (zonas)
                                  Retorna opções ─────────────────→
4. Seleciona tier de entrega
   (same-day, next-day, etc.)
5. Seleciona pagamento
6. Confirma pedido ─────────────→ Valida frete server-side
                                  Cria order com deliveryFee ≠ 0
                                  Processa pagamento
                                  Notifica vendedor ──────────────→ Recebe notificação
                                                                    "Novo pedido!"

                                                                    7. Prepara pedido
                                                                    8. Marca "Pronto para
                                                                       coleta"
                                  ←─── sellerReadyAt = now

                                  9. Na próxima janela de despacho:
                                     Agrupa pedido em rota
                                     Atribui motoboy

                                  10. Motoboy coleta do vendedor
                                      collectedAt = now
                                      Status → "shipped"
Recebe notificação ←───────────── Notifica: "Pedido a caminho!"

                                  11. Motoboy entrega ao comprador
                                      (ou deposita no ponto de retirada)
                                      deliveredAt na stop

12. Confirma entrega ───────────→ deliveryConfirmedAt = now
    (QR code ou manual)           paymentSplit.status = "held"
                                  heldUntil = now + 24h

                                  13. Após 24h:
                                      paymentSplit.status = "released"
                                      Wallet: pending → available
                                                                    Recebe notificação
                                                                    "Pagamento liberado!"
```

### 9.1 Status Flow Atualizado

```
pending ──→ confirmed ──→ preparing ──→ ready ──→ shipped ──→ delivered
  │            │                          │          │            │
  │         (pagamento               (vendedor    (motoboy    (comprador
  │          aprovado)               marcou       coletou)    confirmou
  │                                  pronto)                  entrega)
  │
  └──→ cancelled (a qualquer momento antes de "shipped")
```

Novo status intermediário "ready" agora tem significado concreto: **vendedor preparou o pacote e está aguardando coleta do motoboy**.

---

## 10. Pontos de Retirada

### 10.1 Estratégia

Pontos de retirada são comércios parceiros que aceitam receber pacotes. Vantagens:

- **Para o comprador:** frete mais barato (50% off), retira quando quiser
- **Para o marketplace:** motoboy entrega N pacotes num lugar só (eficiência)
- **Para o comércio parceiro:** recebe comissão + tráfego de pessoas na loja

### 10.2 Critérios para Ponto de Retirada

- Estabelecimento com horário comercial regular
- Espaço para armazenar pacotes (mínimo 20 simultâneos)
- Localização central na cidade/bairro
- Disposição para receber treinamento simples (receber/entregar pacotes com QR code)

### 10.3 Fluxo de Retirada

```
1. Comprador escolhe "Retirar no ponto" no checkout
2. Motoboy entrega pacote(s) no ponto de retirada
3. Ponto armazena (até maxHoldDays, ex: 5 dias)
4. Comprador vai ao ponto, apresenta QR code ou código numérico
5. Funcionário do ponto entrega o pacote
6. Comprador confirma no app (mesmo fluxo de hoje)
7. Se não retirar em maxHoldDays → notificação de alerta
8. Se não retirar em maxHoldDays + 2 → retornar ao vendedor
```

### 10.4 Pontos Sugeridos (Concórdia + Região)

| Cidade | Tipo Sugerido | Justificativa |
|---|---|---|
| Concórdia Centro | Farmácia ou papelaria | Alto tráfego central |
| Concórdia Bairro | Mercado de bairro | Conveniência para quem mora longe do centro |
| Seara | Farmácia ou mercado central | Único ponto necessário na cidade |
| Ipumirim | Mercado/armazém | Foco de tráfego na cidade pequena |
| Piratuba | Ponto turístico/comércio | Fluxo de visitantes (termas) |

### 10.5 Comissão

- R$2,00 por pacote recebido e entregue ao comprador
- Pago mensalmente ao ponto parceiro
- Rastreável por coleção Firestore (cada entrega registra o ponto)

---

## 11. Painel do Entregador (Futuro)

### 11.1 Fase 1: WhatsApp

Na Fase 1, o operador envia a lista de paradas por WhatsApp ao motoboy:

```
🛵 Rota #42 — Manhã 01/03

Zona: Seara
Veículo: Moto
Paradas: 4

1. COLETAR de "Loja do João" (Rua X, 123)
   → Entregar a "Maria Silva" (Rua Y, 456 - Seara)
   Pedido: RDB-A1B2C3 | Camiseta P + Calça M
   📱 (49) 99999-1111

2. COLETAR de "Boutique Ana" (Rua Z, 789)
   → Entregar no PONTO "Farmácia São João" (Rua W, 321 - Seara)
   Pedidos: RDB-D4E5F6, RDB-G7H8I9
   2 pacotes

3. → Entregar a "Carlos Souza" (Rua K, 654 - Seara)
   Pedido: RDB-J1K2L3 | Mesa escritório
   📱 (49) 99999-2222
   ⚠️ ITEM GRANDE — baú extra

4. → Entregar a "Ana Oliveira" (Rua L, 987 - Seara)
   Pedido: RDB-M4N5O6 | Fone bluetooth
   📱 (49) 99999-3333
```

### 11.2 Fase 2: Mini-App ou Tela no App Principal

Quando o volume justificar, criar tela dedicada para o entregador:

```
┌─────────────────────────────────────────────┐
│ 🛵 Minha Rota — Manhã                      │
│ Zona: Seara | 4 paradas | ~45min           │
│                                             │
│ ┌─ 1. Coletar ──────────────────────────┐  │
│ │ 📦 Loja do João                       │  │
│ │    Rua X, 123 — Concórdia             │  │
│ │    [Navegar]  [Coletado ✓]            │  │
│ └───────────────────────────────────────┘  │
│     │                                       │
│     ▼                                       │
│ ┌─ 1. Entregar ─────────────────────────┐  │
│ │ 👤 Maria Silva                        │  │
│ │    Rua Y, 456 — Seara                 │  │
│ │    📱 (49) 99999-1111                 │  │
│ │    [Navegar]  [Entregue ✓]            │  │
│ └───────────────────────────────────────┘  │
│     │                                       │
│     ▼                                       │
│ ┌─ 2. Coletar ──────────────────────────┐  │
│ │ 📦 Boutique Ana                       │  │
│ │    ...                                │  │
│ └───────────────────────────────────────┘  │
│                                             │
│ [Finalizar Rota]                            │
└─────────────────────────────────────────────┘
```

**Features do mini-app:**
- Lista de paradas na ordem otimizada
- Botão "Navegar" → abre Google Maps/Waze
- Botão "Coletado" / "Entregue" → atualiza status no Firestore
- Botão "Problema" → marca falha (destinatário ausente, endereço errado)
- Ligar para comprador/vendedor direto do app

---

## 12. Firestore Rules e Indexes

### 12.1 Novas Rules

```javascript
// delivery_zones — público para leitura, admin-only para escrita
match /delivery_zones/{zoneId} {
  allow read: if true;
  allow write: if false; // Apenas Admin SDK
}

// pickup_points — público para leitura, admin-only para escrita
match /pickup_points/{pointId} {
  allow read: if true;
  allow write: if false; // Apenas Admin SDK
}

// delivery_routes — apenas admin/operador e entregador atribuído
match /delivery_routes/{routeId} {
  // Operador (admin do tenant) ou entregador atribuído podem ler
  allow read: if request.auth != null && (
    isAdmin() ||
    resource.data.driverId == request.auth.uid
  );

  // Apenas Admin SDK cria/modifica rotas
  allow create, update, delete: if false;
}
```

### 12.2 Novos Indexes

```json
{
  "collectionGroup": "delivery_zones",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "sortOrder", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "pickup_points",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "zoneId", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "delivery_routes",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "date", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "delivery_routes",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "driverId", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "orders",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "sellerReadyAt", "order": "ASCENDING" },
    { "fieldPath": "deliveryTier", "order": "ASCENDING" }
  ]
}
```

### 12.3 Alterações em Rules Existentes (orders)

```javascript
match /orders/{orderId} {
  // Adicionar campos permitidos no update do seller:
  allow update: if (isTenantMember(resource.data.tenantId) &&
    affectedKeys().hasOnly([
      'status', 'statusHistory', 'updatedAt',
      'sellerReadyAt',           // ← NOVO: vendedor marca pronto
      'trackingCode',            // já existia
      'shippingCompany'          // já existia
    ]));

  // Buyer update permanece igual (deliveryConfirmedAt)
}
```

---

## 13. Casos de Borda e Tratamento de Erros

### 13.1 Endereço Fora da Área

**Cenário:** Comprador cadastra endereço em Florianópolis e tenta comprar de vendedor em Concórdia.

**Tratamento:**
- `POST /api/shipping/calculate` retorna `{ available: false, error: "OUT_OF_DELIVERY_AREA" }`
- No checkout, step de delivery mostra: "Infelizmente ainda não entregamos nesta região. Atendemos Concórdia e cidades próximas." + botão "Trocar endereço"
- O botão "Continuar" fica desabilitado

### 13.2 Same-Day Após Cutoff

**Cenário:** Comprador tenta same-day às 15h.

**Tratamento:**
- Opção same-day aparece desabilitada com texto: "Disponível para pedidos até 14h"
- Seleciona automaticamente next-day como padrão

### 13.3 Vendedor Não Marca "Pronto"

**Cenário:** Vendedor aceita pedido mas não marca como pronto em 24h.

**Tratamento:**
- Após 12h: notificação ao vendedor: "Você tem um pedido aguardando preparação"
- Após 24h: notificação ao vendedor + comprador: "Seu pedido ainda está sendo preparado pelo vendedor"
- Após 48h: comprador pode solicitar cancelamento com reembolso automático
- Métrica: `seller_preparation_time_avg` — vendedores lentos recebem alerta

### 13.4 Motoboy Não Consegue Entregar

**Cenário:** Destinatário ausente ou endereço errado.

**Tratamento:**
- Motoboy marca stop como `failed` com motivo
- Pedido volta para fila de rotas com prioridade elevada (+30 pontos)
- Comprador recebe notificação: "Não conseguimos entregar. Nova tentativa amanhã."
- Após 2 tentativas falhas: pedido move para ponto de retirada mais próximo
- Após 5 dias no ponto sem retirada: retorna ao vendedor

### 13.5 Pedido Multi-Vendedor (Futuro)

**Cenário atual:** O carrinho é sempre de um vendedor só (validação em `payments.ts`).

**Se no futuro permitir multi-vendedor:**
- Cada vendedor gera uma "sub-entrega" separada
- Frete calculado por vendedor (o motoboy coleta em N vendedores)
- Comprador paga frete por vendedor (ou maior frete + frete reduzido para os demais)
- Para a Fase 1, manter a restrição de vendedor único — simplifica muito

### 13.6 Zona Desativada Temporariamente

**Cenário:** Estrada para Piratuba bloqueada (enchente, deslizamento).

**Tratamento:**
- Operador desativa a zona (`isActive = false`)
- Pedidos já criados para essa zona: operador decide (remarcar ou cancelar)
- Novos pedidos: zona não aparece como opção de entrega
- Mensagem: "Entregas para Piratuba temporariamente indisponíveis"

### 13.7 Produto Sem Peso/Dimensões

**Cenário:** Vendedor cadastra produto sem informar peso.

**Tratamento:**
- Backend assume peso padrão: 0.5kg por unidade
- Backend assume dimensões padrão: 20x15x10cm (cabe na moto)
- Log de warning para auditoria: "Product {id} missing weight, using default"
- No cadastro do produto, campo peso é "recomendado" mas não obrigatório (facilita adoção)
- Fase 2: tornar peso obrigatório para publicar no marketplace

### 13.8 Frete Grátis + Item Pesado

**Cenário:** Comprador atinge freeDeliveryMinimum mas tem item de 15kg que precisa de van.

**Tratamento:**
- Frete grátis anula APENAS o `basePrice` da zona
- `weightSurcharge` (R$20) + `volumeSurcharge` (R$5) permanecem
- Total do frete: R$25 (não é "grátis" de verdade, mas o base foi anulado)
- UI mostra: "Frete base grátis! Adicional de peso/volume: R$25,00"

### 13.9 Ponto de Retirada Lotado

**Cenário:** Ponto atingiu `maxPackages`.

**Tratamento:**
- `POST /api/shipping/calculate` não retorna esse ponto como opção
- Se todos os pontos da zona estiverem lotados, opção pickup_point não aparece
- Comprador só vê opções de entrega em domicílio

### 13.10 Comprador e Vendedor na Mesma Cidade Que Não é Concórdia

**Cenário:** Vendedor em Seara, comprador em Seara.

**Tratamento:**
- Zona 0 relativa ao vendedor = Seara intra-cidade
- Frete base = R$6,90 (mesma lógica da Zona 0 de Concórdia)
- Tiers disponíveis: next-day e agendado (same-day só em Concórdia na Fase 1)
- **Implementação:** na resolução de zona, a distância é calculada entre o endereço do vendedor e o endereço do comprador, não a partir de Concórdia. A zona é determinada pela distância, não pela localização absoluta.

---

## 14. Fases de Implementação

### Fase 1 — MVP de Logística (4-6 semanas)

**Escopo:**
- [ ] Coleção `delivery_zones` com as 8 zonas definidas (seed data)
- [ ] Endpoint `POST /api/shipping/calculate` (cálculo de frete completo)
- [ ] Endpoint `GET /api/shipping/zones` (lista de zonas)
- [ ] Alteração no `POST /api/orders` (frete validado server-side)
- [ ] Novo step "Delivery" no checkout (seleção de tier)
- [ ] `cart_summary.dart` mostrando frete real
- [ ] Campos `weight` e `isPerishable` no `ProductModel` (opcionais)
- [ ] `tenant.address` migrar de String para AddressModel
- [ ] Botão "Pronto para Coleta" no seller order details
- [ ] Tela "Onde entregamos" (informativa)
- [ ] `deliveryFee` incluído no total do pedido (payment split ajustado)
- [ ] Firestore rules e indexes novos

**NÃO inclui na Fase 1:**
- Pontos de retirada (sem parceiros ainda)
- Rotas automatizadas (operador envia por WhatsApp)
- Mini-app do entregador
- Dimensões do produto (só peso)
- Otimização de rota (Google Directions)

### Fase 2 — Pontos de Retirada e Rotas (4-6 semanas após Fase 1)

**Escopo:**
- [ ] Coleção `pickup_points` + endpoints
- [ ] Opção "Retirar no ponto" no checkout
- [ ] Coleção `delivery_routes` + endpoint de geração
- [ ] Painel web/tela de gestão de rotas (operador)
- [ ] Notificações de "vendedor atrasado" (12h/24h/48h)
- [ ] Campo `dimensions` no ProductModel (obrigatório)
- [ ] `shippingCategory` no ProductModel (perecível, frágil, etc.)
- [ ] Métricas: tempo médio de preparação, taxa de entrega com sucesso

### Fase 3 — Automação e Escala (6-8 semanas após Fase 2)

**Escopo:**
- [ ] Mini-app/tela do entregador
- [ ] Rotas geradas automaticamente a cada janela de despacho (Cloud Function scheduled)
- [ ] Integração com Google Directions API para sequenciamento de paradas
- [ ] Rastreamento em tempo real (entregador compartilha localização)
- [ ] Combinação automática de zonas adjacentes com poucos pedidos
- [ ] Dashboard de logística (KPIs: entregas/dia, tempo médio, custo/entrega)
- [ ] Comissão automática para pontos de retirada
- [ ] Sistema de avaliação do entregador (comprador avalia a entrega)

---

## 15. Métricas e Monitoramento

### 15.1 KPIs Operacionais

| Métrica | Meta | Como Medir |
|---|---|---|
| Tempo pedido→entrega (same-day) | < 4h | `deliveredAt - createdAt` onde tier = same_day |
| Tempo pedido→entrega (next-day) | < 24h | `deliveredAt - createdAt` onde tier = next_day |
| Taxa de entrega com sucesso | > 95% | stops com status `delivered` / total stops |
| Taxa de falha na primeira tentativa | < 5% | stops com status `failed` / total stops |
| Tempo de preparação do vendedor | < 4h | `sellerReadyAt - orderConfirmedAt` |
| Custo médio por entrega | < R$8 | custo operacional / entregas totais |
| Pedidos por rota | > 4 | média de stops por rota |
| Entregas por motoboy/dia | 10-15 | total deliveries / driver / day |
| Receita de frete vs custo | > 1.0x | receita de deliveryFee / custo operacional |

### 15.2 Alertas

| Alerta | Condição | Ação |
|---|---|---|
| Vendedor lento | sellerReadyAt - confirmedAt > 12h | Notificação push ao vendedor |
| Pedido preso | createdAt > 48h sem sellerReadyAt | Notificar operador + comprador |
| Rota atrasada | rota status = in_progress > 3h | Verificar com motoboy |
| Ponto de retirada lotado | currentPackages >= maxPackages * 0.8 | Alertar operador para redistribuir |
| Tentativas de entrega | 2+ falhas no mesmo pedido | Redirecionar para ponto de retirada |

### 15.3 Analytics (Firestore)

Coleção `delivery_metrics` (agregado diário, gerado por Cloud Function):

```typescript
// delivery_metrics/{date}
{
  date: "2026-03-01",
  totalOrders: 12,
  totalDeliveries: 10,
  totalPickups: 2,
  deliveriesByZone: {
    zone_concordia: 6,
    zone_seara: 3,
    zone_ipumirim: 1
  },
  deliveriesByTier: {
    same_day: 3,
    next_day: 5,
    scheduled: 2,
    pickup_point: 2
  },
  avgDeliveryTimeMinutes: {
    same_day: 180,     // 3h
    next_day: 1020,    // 17h
    scheduled: 2880    // 48h
  },
  avgSellerPrepTimeMinutes: 240,
  totalFreightRevenue: 89.60,
  failedDeliveries: 1,
  failureReasons: {
    "recipient_absent": 1
  },
  routesDispatched: 3,
  avgStopsPerRoute: 4.0,
  driverPerformance: {
    "driver_1": { deliveries: 6, avgTimePerStop: 15 },
    "driver_2": { deliveries: 4, avgTimePerStop: 18 }
  }
}
```

---

## Apêndice A: CEPs da Região

| Cidade | CEP Principal | Prefixo p/ Match |
|---|---|---|
| Concórdia | 89700-000 | 89700, 89701, 89702, 89703, 89704, 89705, 89706, 89707, 89708, 89709 |
| Lindóia do Sul | 89735-000 | 89735 |
| Peritiba | 89660-000 | 89660 |
| Seara | 89770-000 | 89770 |
| Ipumirim | 89790-000 | 89790 |
| Itá | 89760-000 | 89760 |
| Piratuba | 89667-000 | 89667 |
| Capinzal | 89665-000 | 89665 |
| Ouro | 89663-000 | 89663 |
| Presidente Castello Branco | 89670-000 | 89670 |
| Alto Bela Vista | 89730-000 | 89730 |
| Arabutã | 89737-000 | 89737 |

> **Nota:** CEPs de cidades pequenas podem ter apenas um prefixo (ex: 89770-000 para todo o município de Seara). Validar com a base de CEPs dos Correios antes de implementar.

## Apêndice B: Cálculo de Distância por Coordenadas (Fallback)

Para o fallback de resolução de zona (quando CEP e cidade não batem), usar a fórmula de Haversine:

```typescript
function haversineDistanceKm(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371; // Raio da Terra em km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2
          + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2))
          * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg: number): number {
  return deg * (Math.PI / 180);
}
```

**Coordenadas centrais (aproximadas) das cidades:**

| Cidade | Latitude | Longitude |
|---|---|---|
| Concórdia | -27.2342 | -52.0278 |
| Seara | -27.1487 | -52.3108 |
| Ipumirim | -27.0769 | -52.1297 |
| Piratuba | -27.4247 | -51.7664 |
| Peritiba | -27.3747 | -51.9083 |
| Itá | -27.2870 | -52.3220 |
| Lindóia do Sul | -27.0536 | -52.0678 |
| Capinzal | -27.3444 | -51.6144 |

> **Nota:** Estas coordenadas são aproximadas (centro da cidade). Para produção, usar centroide do município via IBGE ou Google Geocoding API.

## Apêndice C: Decisões Arquiteturais e Justificativas

| Decisão | Alternativa Descartada | Justificativa |
|---|---|---|
| Zonas por CEP (não por distância km) | Cálculo por km exato | CEP é determinístico, não precisa de geocoding API, previsível pro comprador |
| Frete calculado no backend | Cálculo no cliente | Previne manipulação de preço, mesma razão que os preços dos produtos já são validados server-side |
| Rotas por zona (não cross-zone) | Rotas otimizadas cross-zone | Simplicidade > otimalidade na Fase 1; zonas adjacentes podem ser combinadas manualmente |
| Frete grátis não anula peso/volume | Frete 100% grátis sem exceção | Evita subsídio de itens pesados que custam caro pra entregar; sustentabilidade financeira |
| Platform fee NÃO incide sobre frete | Taxa sobre valor total incluindo frete | Frete não é receita do vendedor; cobrar taxa sobre frete geraria percepção de injustiça |
| Peso default 0.5kg | Obrigar peso em todo produto | Facilita onboarding de vendedores; peso errado é melhor que produto sem peso bloqueando publicação |
| WhatsApp pra motoboy na Fase 1 | App do motoboy desde o início | YAGNI — volume baixo não justifica dev cost de app próprio; WhatsApp resolve até ~30 entregas/dia |
| Pedido sempre de 1 vendedor | Permitir multi-vendedor | Mantém a simplicidade existente; split de frete multi-vendor é complexo e desnecessário para volume inicial |

---

*Documento criado em 28/02/2026. Atualizar conforme decisões de negócio evoluam.*
