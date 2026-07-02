// socketAdapter.js — AparCar AWS AppSync adapter
// Replaces Socket.io server.js
// Author: Pietro | Generated: July 2026

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
    $spotId: String!
    $userId: String!
    $carDetails: String!
  ) {
    requestSpot(
      spotId: $spotId
      userId: $userId
      carDetails: $carDetails
    ) {
      success
      exchangeId
      error
    }
  }
`;

const CONFIRM_EXCHANGE = `
  mutation ConfirmExchange($exchangeId: String!, $role: String!) {
    confirmExchange(exchangeId: $exchangeId, role: $role) {
      success
      status
      error
    }
  }
`;

const CANCEL_EXCHANGE = `
  mutation CancelExchange($exchangeId: String!, $role: String!) {
    cancelExchange(exchangeId: $exchangeId, role: $role) {
      success
      error
    }
  }
`;

const UPDATE_LOCATION = `
  mutation UpdateLocation(
    $exchangeId: String!
    $lat: Float!
    $lng: Float!
  ) {
    updateLocation(exchangeId: $exchangeId, lat: $lat, lng: $lng)
  }
`;

// ─── Subscriptions ────────────────────────────────────────────────────────────

const ON_SPOTS_UPDATE = `
  subscription OnSpotsUpdate {
    onSpotsUpdate {
      signalId
      user
      carDetails
      lat
      lng
      timerMinutes
      expiresAt
    }
  }
`;

// ─── API Functions ────────────────────────────────────────────────────────────

/**
 * Driver taps "I'm leaving"
 * @param {string} user - User identifier
 * @param {string} carDetails - Car description
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @param {number} timer_minutes - Timer in minutes (1-30)
 * @returns {Promise<{success, signalId, expiresAt, earlyWarningAt, timerMinutes, error}>}
 */
export async function createParkingSignal({ user, carDetails, lat, lng, timer_minutes }) {
  const result = await client.graphql({
    query: CREATE_PARKING_SIGNAL,
    variables: { user, carDetails, lat, lng, timer_minutes },
  });
  return result.data.createParkingSignal;
}

/**
 * Driver taps "I'm looking"
 * STUB — returns mock success until look-signal-handler is built
 * @param {string} userId
 * @param {number} lat
 * @param {number} lng
 * @param {number} radius_meters
 */
export async function registerLookingDriver({ userId, lat, lng, radius_meters }) {
  const result = await client.graphql({
    query: REGISTER_LOOKING_DRIVER,
    variables: { userId, lat, lng, radius_meters },
  });
  return result.data.registerLookingDriver;
}

/**
 * Looking driver requests a spot
 * STUB — returns mock success until requestSpot handler is built
 */
export async function requestSpot({ spotId, userId, carDetails }) {
  const result = await client.graphql({
    query: REQUEST_SPOT,
    variables: { spotId, userId, carDetails },
  });
  return result.data.requestSpot;
}

/**
 * Confirm exchange (both parties)
 * STUB — returns mock success
 */
export async function confirmExchange({ exchangeId, role }) {
  const result = await client.graphql({
    query: CONFIRM_EXCHANGE,
    variables: { exchangeId, role },
  });
  return result.data.confirmExchange;
}

/**
 * Cancel exchange
 * STUB — returns mock success
 */
export async function cancelExchange({ exchangeId, role }) {
  const result = await client.graphql({
    query: CANCEL_EXCHANGE,
    variables: { exchangeId, role },
  });
  return result.data.cancelExchange;
}

/**
 * Update location during active exchange
 * STUB — returns mock success
 */
export async function updateLocation({ exchangeId, lat, lng }) {
  const result = await client.graphql({
    query: UPDATE_LOCATION,
    variables: { exchangeId, lat, lng },
  });
  return result.data.updateLocation;
}

/**
 * Subscribe to real-time parking spot updates
 * @param {function} onData - callback receives spot update
 * @param {function} onError - callback receives error
 * @returns {object} subscription handle — call .unsubscribe() to stop
 */
export function subscribeToSpotUpdates({ onData, onError }) {
  const subscription = client.graphql({
    query: ON_SPOTS_UPDATE,
  }).subscribe({
    next: ({ data }) => {
      if (data?.onSpotsUpdate) {
        onData(data.onSpotsUpdate);
      }
    },
    error: (error) => {
      console.error('[AparCar] Subscription error:', error);
      if (onError) onError(error);
    },
  });

  return subscription;
}