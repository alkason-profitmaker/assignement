/**
 * Root Navigator - Handles auth flow and main app navigation
 */
import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ActivityIndicator, View, StyleSheet } from 'react-native';

import { useAuth } from '../services/AuthContext';

// Screens
import LoginScreen from '../screens/LoginScreen';
import OTPScreen from '../screens/OTPScreen';
import HomeScreen from '../screens/HomeScreen';
import FileUploadScreen from '../screens/FileUploadScreen';
import CollageScreen from '../screens/CollageScreen';
import PreviewScreen from '../screens/PreviewScreen';
import PaymentScreen from '../screens/PaymentScreen';
import QRScannerScreen from '../screens/QRScannerScreen';
import PrintStatusScreen from '../screens/PrintStatusScreen';
import OrderHistoryScreen from '../screens/OrderHistoryScreen';
import ProfileScreen from '../screens/ProfileScreen';

// Navigation types
export type RootStackParamList = {
  // Auth screens
  Login: undefined;
  OTP: { phoneNumber: string };

  // Main screens
  Home: undefined;
  FileUpload: undefined;
  Collage: { images: string[] };
  Preview: { files: any[]; collageConfig?: any };
  Payment: { orderId: number; orderNumber: string; amount: number };
  QRScanner: { orderNumber: string };
  PrintStatus: { orderNumber: string };
  OrderHistory: undefined;
  Profile: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  const { isLoading, isAuthenticated } = useAuth();

  // Show loading spinner while checking auth
  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: '#2196F3' },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: 'bold' },
      }}
    >
      {!isAuthenticated ? (
        // Auth Stack
        <>
          <Stack.Screen
            name="Login"
            component={LoginScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="OTP"
            component={OTPScreen}
            options={{ title: 'Verify OTP' }}
          />
        </>
      ) : (
        // Main App Stack
        <>
          <Stack.Screen
            name="Home"
            component={HomeScreen}
            options={{ title: 'PrintHub' }}
          />
          <Stack.Screen
            name="FileUpload"
            component={FileUploadScreen}
            options={{ title: 'Select Files' }}
          />
          <Stack.Screen
            name="Collage"
            component={CollageScreen}
            options={{ title: 'Create Collage' }}
          />
          <Stack.Screen
            name="Preview"
            component={PreviewScreen}
            options={{ title: 'Preview & Price' }}
          />
          <Stack.Screen
            name="Payment"
            component={PaymentScreen}
            options={{ title: 'Payment' }}
          />
          <Stack.Screen
            name="QRScanner"
            component={QRScannerScreen}
            options={{ title: 'Scan QR to Print' }}
          />
          <Stack.Screen
            name="PrintStatus"
            component={PrintStatusScreen}
            options={{ title: 'Print Status' }}
          />
          <Stack.Screen
            name="OrderHistory"
            component={OrderHistoryScreen}
            options={{ title: 'My Orders' }}
          />
          <Stack.Screen
            name="Profile"
            component={ProfileScreen}
            options={{ title: 'Profile' }}
          />
        </>
      )}
    </Stack.Navigator>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});
