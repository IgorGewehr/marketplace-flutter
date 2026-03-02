/**
 * Seed script for delivery zones and pickup points.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/scripts/seed-delivery-zones.ts
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS or Firebase Admin default credentials.
 */

import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

interface DeliveryZone {
  id: string;
  name: string;
  description: string;
  basePrice: number;
  freeDeliveryMinimum: number;
  sameDayAvailable: boolean;
  nextDayAvailable: boolean;
  scheduledAvailable: boolean;
  estimatedDelivery: string;
  sortOrder: number;
  isActive: boolean;
  zipPrefixes: string[];
  citiesLowercase: string[];
  maxDistanceKm: number;
  adjacentZones: string[];
  coordinates?: { lat: number; lng: number };
  createdAt: admin.firestore.FieldValue;
  updatedAt: admin.firestore.FieldValue;
}

const zones: DeliveryZone[] = [
  {
    id: "zone_0",
    name: "Concórdia Centro",
    description: "Centro e bairros próximos de Concórdia",
    basePrice: 3.90,
    freeDeliveryMinimum: 80,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 2-4 dias úteis",
    sortOrder: 0,
    isActive: true,
    zipPrefixes: ["89700", "89701", "89702", "89703"],
    citiesLowercase: ["concórdia", "concordia"],
    maxDistanceKm: 10,
    adjacentZones: ["zone_1", "zone_2", "zone_3"],
    coordinates: { lat: -27.2343, lng: -52.0278 },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_1",
    name: "Lindóia do Sul",
    description: "Município de Lindóia do Sul",
    basePrice: 4.90,
    freeDeliveryMinimum: 120,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 3-5 dias úteis",
    sortOrder: 1,
    isActive: true,
    zipPrefixes: ["89735"],
    citiesLowercase: ["lindóia do sul", "lindoia do sul"],
    maxDistanceKm: 20,
    adjacentZones: ["zone_0"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_2",
    name: "Peritiba",
    description: "Município de Peritiba",
    basePrice: 5.90,
    freeDeliveryMinimum: 120,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 3-5 dias úteis",
    sortOrder: 2,
    isActive: true,
    zipPrefixes: ["89750"],
    citiesLowercase: ["peritiba"],
    maxDistanceKm: 25,
    adjacentZones: ["zone_0", "zone_5"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_3",
    name: "Seara",
    description: "Município de Seara",
    basePrice: 5.90,
    freeDeliveryMinimum: 130,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 3-5 dias úteis",
    sortOrder: 3,
    isActive: true,
    zipPrefixes: ["89770"],
    citiesLowercase: ["seara"],
    maxDistanceKm: 30,
    adjacentZones: ["zone_0", "zone_4"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_4",
    name: "Ipumirim",
    description: "Município de Ipumirim",
    basePrice: 6.90,
    freeDeliveryMinimum: 150,
    sameDayAvailable: false,
    nextDayAvailable: true,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 3-5 dias úteis",
    sortOrder: 4,
    isActive: true,
    zipPrefixes: ["89790"],
    citiesLowercase: ["ipumirim"],
    maxDistanceKm: 40,
    adjacentZones: ["zone_3"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_5",
    name: "Itá",
    description: "Município de Itá",
    basePrice: 7.90,
    freeDeliveryMinimum: 180,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 5-8 dias úteis",
    sortOrder: 5,
    isActive: true,
    zipPrefixes: ["89760"],
    citiesLowercase: ["itá", "ita"],
    maxDistanceKm: 50,
    adjacentZones: ["zone_2", "zone_6"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_6",
    name: "Piratuba",
    description: "Município de Piratuba",
    basePrice: 7.90,
    freeDeliveryMinimum: 180,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 5-8 dias úteis",
    sortOrder: 6,
    isActive: true,
    zipPrefixes: ["89667"],
    citiesLowercase: ["piratuba"],
    maxDistanceKm: 55,
    adjacentZones: ["zone_5", "zone_7"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: "zone_7",
    name: "Capinzal / Ouro",
    description: "Municípios de Capinzal e Ouro",
    basePrice: 8.90,
    freeDeliveryMinimum: 200,
    sameDayAvailable: false,
    nextDayAvailable: false,
    scheduledAvailable: true,
    estimatedDelivery: "Estimativa: 5-8 dias úteis",
    sortOrder: 7,
    isActive: true,
    zipPrefixes: ["89665", "89663"],
    citiesLowercase: ["capinzal", "ouro"],
    maxDistanceKm: 60,
    adjacentZones: ["zone_6"],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

interface PickupPoint {
  id: string;
  name: string;
  type: string;
  zoneId: string;
  address: {
    street: string;
    number: string;
    neighborhood: string;
    city: string;
    state: string;
    zipCode: string;
  };
  businessHours: Record<string, string>;
  maxHoldDays: number;
  isActive: boolean;
  createdAt: admin.firestore.FieldValue;
  updatedAt: admin.firestore.FieldValue;
}

const pickupPoints: PickupPoint[] = [
  {
    id: "pickup_concordia_centro",
    name: "Ponto de Retirada — Centro Concórdia",
    type: "store",
    zoneId: "zone_0",
    address: {
      street: "Rua Marechal Deodoro",
      number: "500",
      neighborhood: "Centro",
      city: "Concórdia",
      state: "SC",
      zipCode: "89700-000",
    },
    businessHours: {
      "mon-fri": "08:00-18:00",
      "sat": "08:00-12:00",
    },
    maxHoldDays: 7,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

async function seed() {
  console.log("Seeding delivery zones...");

  const batch = db.batch();

  for (const zone of zones) {
    const { id, ...data } = zone;
    batch.set(db.collection("delivery_zones").doc(id), data);
    console.log(`  + ${id}: ${zone.name} (R$${zone.basePrice.toFixed(2)})`);
  }

  for (const point of pickupPoints) {
    const { id, ...data } = point;
    batch.set(db.collection("pickup_points").doc(id), data);
    console.log(`  + ${id}: ${point.name}`);
  }

  await batch.commit();
  console.log(`\nDone! Seeded ${zones.length} zones and ${pickupPoints.length} pickup points.`);
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Seed failed:", err);
    process.exit(1);
  });
