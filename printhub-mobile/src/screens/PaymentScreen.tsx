/**
 * Payment Screen - Handle UPI payment via Razorpay
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Linking,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/RootNavigator';
import { paymentsAPI } from '../services/api';

type PaymentScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Payment'>;
  route: RouteProp<RootStackParamList, 'Payment'>;
};

interface RazorpayOrder {
  razorpay_order_id: string;
  amount: number;
  currency: string;
  key_id: string;
  order_number: string;
}

export default function PaymentScreen({ navigation, route }: PaymentScreenProps) {
  const { orderId, orderNumber, amount } = route.params;
  const [isLoading, setIsLoading] = useState(true);
  const [razorpayOrder, setRazorpayOrder] = useState<RazorpayOrder | null>(null);
  const [paymentStatus, setPaymentStatus] = useState<'pending' | 'processing' | 'success' | 'failed'>('pending');

  useEffect(() => {
    initiatePayment();
  }, []);

  const initiatePayment = async () => {
    try {
      setIsLoading(true);
      const response = await paymentsAPI.initiatePayment(orderId);
      setRazorpayOrder(response.data);
    } catch (error: any) {
      Alert.alert('Error', error.response?.data?.detail || 'Failed to initiate payment');
      navigation.goBack();
    } finally {
      setIsLoading(false);
    }
  };

  const handlePayWithUPI = async (upiApp: string) => {
    if (!razorpayOrder) return;

    setPaymentStatus('processing');

    // In a real app, you would use react-native-razorpay SDK
    // For this MVP, we'll simulate the payment flow

    try {
      // Simulate payment processing
      // In production: Use RazorpayCheckout.open()

      // Mock successful payment for development
      const mockPaymentId = `pay_${Date.now()}`;
      const mockSignature = 'mock_signature_for_development';

      // Verify payment with backend
      const verifyResponse = await paymentsAPI.verifyPayment({
        razorpay_order_id: razorpayOrder.razorpay_order_id,
        razorpay_payment_id: mockPaymentId,
        razorpay_signature: mockSignature,
      });

      if (verifyResponse.data.success) {
        setPaymentStatus('success');

        // Show success and navigate to QR scanner
        setTimeout(() => {
          Alert.alert(
            'Payment Successful!',
            `Order #${orderNumber}\n\nGo to the printer station and scan the QR code to print.`,
            [
              {
                text: 'Scan QR to Print',
                onPress: () => navigation.replace('QRScanner', { orderNumber }),
              },
            ]
          );
        }, 500);
      } else {
        setPaymentStatus('failed');
        Alert.alert('Payment Failed', verifyResponse.data.message || 'Please try again');
      }
    } catch (error: any) {
      setPaymentStatus('failed');
      Alert.alert('Payment Failed', error.response?.data?.detail || 'Please try again');
    }
  };

  const handleRetry = () => {
    setPaymentStatus('pending');
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Preparing payment...</Text>
      </View>
    );
  }

  if (paymentStatus === 'processing') {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Processing payment...</Text>
        <Text style={styles.loadingSubtext}>Please complete payment in your UPI app</Text>
      </View>
    );
  }

  if (paymentStatus === 'success') {
    return (
      <View style={styles.successContainer}>
        <Text style={styles.successIcon}>✓</Text>
        <Text style={styles.successTitle}>Payment Successful!</Text>
        <Text style={styles.successText}>Order #{orderNumber}</Text>
      </View>
    );
  }

  if (paymentStatus === 'failed') {
    return (
      <View style={styles.failedContainer}>
        <Text style={styles.failedIcon}>✕</Text>
        <Text style={styles.failedTitle}>Payment Failed</Text>
        <Text style={styles.failedText}>Please try again</Text>
        <TouchableOpacity style={styles.retryButton} onPress={handleRetry}>
          <Text style={styles.retryButtonText}>Retry Payment</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Order Summary */}
      <View style={styles.summaryCard}>
        <Text style={styles.orderNumber}>Order #{orderNumber}</Text>
        <Text style={styles.amount}>₹{amount}</Text>
      </View>

      {/* UPI Apps */}
      <View style={styles.upiSection}>
        <Text style={styles.sectionTitle}>Pay with UPI</Text>

        <TouchableOpacity
          style={styles.upiOption}
          onPress={() => handlePayWithUPI('gpay')}
        >
          <View style={[styles.upiIcon, { backgroundColor: '#4285F4' }]}>
            <Text style={styles.upiIconText}>G</Text>
          </View>
          <Text style={styles.upiText}>Google Pay</Text>
          <Text style={styles.arrow}>›</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.upiOption}
          onPress={() => handlePayWithUPI('phonepe')}
        >
          <View style={[styles.upiIcon, { backgroundColor: '#5F259F' }]}>
            <Text style={styles.upiIconText}>P</Text>
          </View>
          <Text style={styles.upiText}>PhonePe</Text>
          <Text style={styles.arrow}>›</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.upiOption}
          onPress={() => handlePayWithUPI('paytm')}
        >
          <View style={[styles.upiIcon, { backgroundColor: '#00BAF2' }]}>
            <Text style={styles.upiIconText}>₹</Text>
          </View>
          <Text style={styles.upiText}>Paytm</Text>
          <Text style={styles.arrow}>›</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.upiOption}
          onPress={() => handlePayWithUPI('other')}
        >
          <View style={[styles.upiIcon, { backgroundColor: '#666' }]}>
            <Text style={styles.upiIconText}>UPI</Text>
          </View>
          <Text style={styles.upiText}>Other UPI App</Text>
          <Text style={styles.arrow}>›</Text>
        </TouchableOpacity>
      </View>

      {/* Security Note */}
      <View style={styles.securityNote}>
        <Text style={styles.securityIcon}>🔒</Text>
        <Text style={styles.securityText}>
          Secure payment powered by Razorpay
        </Text>
      </View>

      {/* Cancel */}
      <TouchableOpacity
        style={styles.cancelButton}
        onPress={() => navigation.goBack()}
      >
        <Text style={styles.cancelButtonText}>Cancel Payment</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 18,
    color: '#333',
    fontWeight: '600',
  },
  loadingSubtext: {
    marginTop: 8,
    fontSize: 14,
    color: '#666',
  },
  successContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#E8F5E9',
  },
  successIcon: {
    fontSize: 64,
    color: '#4CAF50',
    marginBottom: 16,
  },
  successTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#4CAF50',
    marginBottom: 8,
  },
  successText: {
    fontSize: 16,
    color: '#666',
  },
  failedContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFEBEE',
  },
  failedIcon: {
    fontSize: 64,
    color: '#F44336',
    marginBottom: 16,
  },
  failedTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#F44336',
    marginBottom: 8,
  },
  failedText: {
    fontSize: 16,
    color: '#666',
    marginBottom: 24,
  },
  retryButton: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  summaryCard: {
    backgroundColor: '#2196F3',
    padding: 24,
    alignItems: 'center',
  },
  orderNumber: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.8)',
    marginBottom: 8,
  },
  amount: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#fff',
  },
  upiSection: {
    padding: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  upiOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 8,
    marginBottom: 8,
  },
  upiIcon: {
    width: 44,
    height: 44,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  upiIconText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  upiText: {
    flex: 1,
    fontSize: 16,
    color: '#333',
    marginLeft: 16,
  },
  arrow: {
    fontSize: 24,
    color: '#ccc',
  },
  securityNote: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  securityIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  securityText: {
    fontSize: 12,
    color: '#999',
  },
  cancelButton: {
    margin: 16,
    padding: 16,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: 16,
    color: '#F44336',
  },
});
