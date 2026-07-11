// socketAdapter.js — AparCar AWS AppSync adapter
// Replaces Socket.io server.js
// Author: Pietro | Updated: July 2026 v2.1.0
// Changes: requestSpot, confirmExchange, cancelExchange signatures updated.
//          submitRating added. updateLocation removed.

import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/api';

// ─── Config ───────────────────────────────────────────────────────────────────

Amplify.configure({
  API: {
    GraphQL: {
      endpoint: 'https://tkocnchm3ndv3euandiu3udc54.appsync-api.eu-west-1.amazonaws.com/graphql',
      region: 'eu-west-1',
      defaultAuthMode: 'apiKey',
      apiKey: 'da2-bzetsicxwvgorgy7zngkbjjsp4',
    },
  },
});

const client = generateClient();

// ─── Mutations ────────────────────────────────────────────────────────────────

const CREATE_PARKING_SIGNAL = `
  mutation CreateParkingSignal(
    $user: String!
    $carDetails: String!
    $lat: Float!
    $lng: Float!
    $timer_minutes: Int!
  ) {
    createParkingSignal(
      user: $user
      carDetails: $carDetails
      lat: $lat
      lng: $lng
      timer_minutes: $timer_minutes
    ) {
      success
      signalId
      expiresAt
      earlyWarningAt
      timerMinutes
      error
    }
  }
`;

const REGISTER_LOOKING_DRIVER = `
  mutation RegisterLookingDriver(
    $userId: String!
    $lat: Float!
    $lng: Float!
    $radius_meters: Int!
  ) {
    registerLookingDriver(
      userId: $userId
      lat: $lat
      lng: $lng
      radius_meters: $radius_meters
    ) {
      success
      lookId
      error
    }
  }
`;

const REQUEST_SPOT = `
  mutation RequestSpot(
    $signalId: String!
    $userId: String!
  ) {
    requestSpot(
      signalId: $signalId
      userId: $userId
    ) {
      success
      exchangeId
      arrivalDeadline
      error
    }
  }
`;

const CONFIRM_EXCHANGE = `
  mutation ConfirmExchange(
    $exchangeId: String!
    $userId: String!
  ) {
    confirmExchange(
      exchangeId: $exchangeId
      userId: $userId
    ) {
      success
      exchangeId
      error
    }
  }
`;

// reason must be one of:
// Driver 1: DRIVER1_CHANGED_MIND | DRIVER1_ALREADY_LEFT | DRIVER1_TIMER_EXPIRED
// Driver 2: DRIVER2_FOUND_OTHER | DRIVER2_TOO_FAR
const CANCEL_EXCHANGE = `
  mutation CancelExchange(
    $exchangeId: String!
    $userId: String!
    $reason: String!
  ) {
    cancelExchange(
      exchangeId: $exchangeId
      userId: $userId
      reason: $reason
    ) {
      success
      exchangeId
      error
    }
  }
`;

const SUBMIT_RATING = `
  mutation SubmitRating(
    $exchangeId: String!
    $userId: String!
    $thumbsUp: Boolean!
  ) {
    submitRating(
      exchangeId: $exchangeId
      userId: $userId
      thumbsUp: $thumbsUp
    ) {
      success
      error
    }
  }
`;

// ─── Subscription ─────────────────────────────────────────────────────────────

const ON_SPOTS_UPDATE = `
  subscription OnSpotsUpdate {
    onSpotsUpdate {
      success
      signalId
      expiresAt
      timerMinutes
      error
    }
  }
`;

// ─── API functions ────────────────────────────────────────────────────────────

export const aparcar = {

  // Driver 1 signals they are leaving
  // Returns: { signalId, expiresAt, earlyWarningAt, timerMinutes }
  async createParkingSignal({ user, carDetails, lat, lng, timer_minutes }) {
    const res = await client.graphql({
      query: CREATE_PARKING_SIGNAL,
      variables: { user, carDetails, lat, lng, timer_minutes },
    });
    return res.data.createParkingSignal;
  },

  // Driver 2 registers as looking for a spot
  // Returns: { lookId }
  async registerLookingDriver({ userId, lat, lng, radius_meters = 500 }) {
    const res = await client.graphql({
      query: REGISTER_LOOKING_DRIVER,
      variables: { userId, lat, lng, radius_meters },
    });
    return res.data.registerLookingDriver;
  },

  // Driver 2 claims a specific spot (after receiving push notification)
  // signalId comes from the push notification payload
  // Returns: { exchangeId, arrivalDeadline } — 10 minute window to arrive
  async requestSpot({ signalId, userId }) {
    const res = await client.graphql({
      query: REQUEST_SPOT,
      variables: { signalId, userId },
    });
    return res.data.requestSpot;
  },

  // Driver 2 confirms they have arrived and parked
  // Returns: { exchangeId }
  // After this, call submitRating
  async confirmExchange({ exchangeId, userId }) {
    const res = await client.graphql({
      query: CONFIRM_EXCHANGE,
      variables: { exchangeId, userId },
    });
    return res.data.confirmExchange;
  },

  // Either driver cancels the exchange
  // Driver 1 reasons: DRIVER1_CHANGED_MIND | DRIVER1_ALREADY_LEFT | DRIVER1_TIMER_EXPIRED
  // Driver 2 reasons: DRIVER2_FOUND_OTHER | DRIVER2_TOO_FAR
  async cancelExchange({ exchangeId, userId, reason }) {
    const res = await client.graphql({
      query: CANCEL_EXCHANGE,
      variables: { exchangeId, userId, reason },
    });
    return res.data.cancelExchange;
  },

  // Submit thumbs up/down after a confirmed exchange
  // thumbsUp: true = thumbs up, false = thumbs down
  // Call after confirmExchange for both drivers
  async submitRating({ exchangeId, userId, thumbsUp }) {
    const res = await client.graphql({
      query: SUBMIT_RATING,
      variables: { exchangeId, userId, thumbsUp },
    });
    return res.data.submitRating;
  },

  // Subscribe to real-time spot updates
  // callback receives { signalId, expiresAt, timerMinutes }
  subscribeToSpotUpdates(callback) {
    return client
      .graphql({ query: ON_SPOTS_UPDATE })
      .subscribe({ next: ({ data }) => callback(data.onSpotsUpdate) });
  },
};

// ─── Maps helper ──────────────────────────────────────────────────────────────
// Call this when user taps a push notification containing lat/lng
// Opens native Maps app at the parking spot coordinates

import { Linking, Platform } from 'react-native';

export function openMapsAtSpot(lat, lng, label = 'Plaza disponible') {
  const encoded = encodeURIComponent(label);
  const url = Platform.select({
    ios: `maps://maps.apple.com/?q=${encoded}&ll=${lat},${lng}`,
    android: `geo:${lat},${lng}?q=${lat},${lng}(${encoded})`,
  });
  const fallback = `https://maps.google.com/?q=${lat},${lng}`;
  Linking.canOpenURL(url)
    .then(supported => Linking.openURL(supported ? url : fallback))
    .catch(() => Linking.openURL(fallback));
}

// ─── Push notification handler ────────────────────────────────────────────────
// Wire this to your Expo notification listener in App.js
// Notifications contain: { signalId, lat, lng, carDetails, timerMinutes, distanceMeters }

import * as Notifications from 'expo-notifications';

export function setupNotificationHandler(onMatch) {
  return Notifications.addNotificationResponseReceivedListener(response => {
    const data = response.notification.request.content.data;
    // data.lat and data.lng are the parking spot coordinates
    // Call onMatch(data) to let your UI handle the match
    // Then call openMapsAtSpot(data.lat, data.lng, data.carDetails) on user tap
    if (onMatch) onMatch(data);
  });
}
