/**
 * Print Status Screen - Show printing progress
 */
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/RootNavigator';
import { printerAPI, ordersAPI } from '../services/api';

type PrintStatusScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'PrintStatus'>;
  route: RouteProp<RootStackParamList, 'PrintStatus'>;
};

interface PrintStatus {
  order_number: string;
  status: string;
  current_page: number;
  total_pages: number;
  progress_percentage: number;
  message: string;
}

export default function PrintStatusScreen({ navigation, route }: PrintStatusScreenProps) {
  const { orderNumber } = route.params;
  const [status, setStatus] = useState<PrintStatus | null>(null);
  const [showRating, setShowRating] = useState(false);
  const [selectedRating, setSelectedRating] = useState(0);
  const progressAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    pollStatus();
    const interval = setInterval(pollStatus, 2000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (status) {
      Animated.timing(progressAnim, {
        toValue: status.progress_percentage,
        duration: 300,
        useNativeDriver: false,
      }).start();

      if (status.status === 'completed') {
        setShowRating(true);
      }
    }
  }, [status]);

  const pollStatus = async () => {
    try {
      const response = await printerAPI.getPrintStatus(orderNumber);
      setStatus(response.data);
    } catch (error) {
      console.error('Failed to get print status:', error);
    }
  };

  const handleRating = async (rating: number) => {
    setSelectedRating(rating);
    try {
      await ordersAPI.rateOrder(orderNumber, rating);
    } catch (error) {
      console.error('Failed to submit rating:', error);
    }
  };

  const getStatusIcon = () => {
    if (!status) return '⏳';
    switch (status.status) {
      case 'printing':
        return '🖨️';
      case 'completed':
        return '✓';
      case 'failed':
        return '✕';
      default:
        return '⏳';
    }
  };

  const getStatusColor = () => {
    if (!status) return '#2196F3';
    switch (status.status) {
      case 'printing':
        return '#2196F3';
      case 'completed':
        return '#4CAF50';
      case 'failed':
        return '#F44336';
      default:
        return '#FF9800';
    }
  };

  const progressWidth = progressAnim.interpolate({
    inputRange: [0, 100],
    outputRange: ['0%', '100%'],
  });

  if (!status) {
    return (
      <View style={styles.container}>
        <Text style={styles.loadingText}>Loading status...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Status Icon */}
      <View style={[styles.iconContainer, { backgroundColor: getStatusColor() }]}>
        <Text style={styles.icon}>{getStatusIcon()}</Text>
      </View>

      {/* Status Message */}
      <Text style={styles.statusTitle}>
        {status.status === 'completed'
          ? 'Print Complete!'
          : status.status === 'failed'
          ? 'Print Failed'
          : 'Printing...'}
      </Text>

      <Text style={styles.orderNumber}>Order #{orderNumber}</Text>

      {/* Progress */}
      {status.status === 'printing' && (
        <View style={styles.progressSection}>
          <View style={styles.progressBar}>
            <Animated.View
              style={[
                styles.progressFill,
                { width: progressWidth, backgroundColor: getStatusColor() },
              ]}
            />
          </View>
          <Text style={styles.progressText}>
            Page {status.current_page} of {status.total_pages}
          </Text>
          <Text style={styles.progressPercent}>{status.progress_percentage}%</Text>
        </View>
      )}

      {/* Completed Info */}
      {status.status === 'completed' && (
        <View style={styles.completedSection}>
          <Text style={styles.completedText}>
            {status.total_pages} pages printed successfully
          </Text>
          <Text style={styles.collectText}>
            Please collect your documents from the tray
          </Text>
        </View>
      )}

      {/* Failed Info */}
      {status.status === 'failed' && (
        <View style={styles.failedSection}>
          <Text style={styles.failedText}>{status.message}</Text>
          <Text style={styles.refundText}>
            Refund will be processed automatically
          </Text>
        </View>
      )}

      {/* Rating */}
      {showRating && status.status === 'completed' && (
        <View style={styles.ratingSection}>
          <Text style={styles.ratingTitle}>Rate your experience</Text>
          <View style={styles.stars}>
            {[1, 2, 3, 4, 5].map((star) => (
              <TouchableOpacity
                key={star}
                onPress={() => handleRating(star)}
                style={styles.starButton}
              >
                <Text
                  style={[
                    styles.star,
                    star <= selectedRating && styles.starSelected,
                  ]}
                >
                  ★
                </Text>
              </TouchableOpacity>
            ))}
          </View>
          {selectedRating > 0 && (
            <Text style={styles.thankYou}>Thank you for your feedback!</Text>
          )}
        </View>
      )}

      {/* Done Button */}
      {(status.status === 'completed' || status.status === 'failed') && (
        <TouchableOpacity
          style={styles.doneButton}
          onPress={() => navigation.navigate('Home')}
        >
          <Text style={styles.doneButtonText}>Done</Text>
        </TouchableOpacity>
      )}

      {/* Waiting Message */}
      {status.status === 'printing' && (
        <View style={styles.waitingMessage}>
          <Text style={styles.waitingIcon}>📍</Text>
          <Text style={styles.waitingText}>
            Please wait at the printer station
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    paddingTop: 48,
    paddingHorizontal: 24,
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  iconContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
  },
  icon: {
    fontSize: 48,
    color: '#fff',
  },
  statusTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  orderNumber: {
    fontSize: 16,
    color: '#666',
    marginBottom: 32,
  },
  progressSection: {
    width: '100%',
    alignItems: 'center',
  },
  progressBar: {
    width: '100%',
    height: 8,
    backgroundColor: '#E0E0E0',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 12,
  },
  progressFill: {
    height: '100%',
    borderRadius: 4,
  },
  progressText: {
    fontSize: 16,
    color: '#333',
    marginBottom: 4,
  },
  progressPercent: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  completedSection: {
    alignItems: 'center',
  },
  completedText: {
    fontSize: 18,
    color: '#4CAF50',
    fontWeight: '600',
    marginBottom: 8,
  },
  collectText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  failedSection: {
    alignItems: 'center',
  },
  failedText: {
    fontSize: 16,
    color: '#F44336',
    marginBottom: 8,
    textAlign: 'center',
  },
  refundText: {
    fontSize: 14,
    color: '#666',
  },
  ratingSection: {
    marginTop: 32,
    alignItems: 'center',
  },
  ratingTitle: {
    fontSize: 16,
    color: '#333',
    marginBottom: 16,
  },
  stars: {
    flexDirection: 'row',
  },
  starButton: {
    padding: 8,
  },
  star: {
    fontSize: 36,
    color: '#ddd',
  },
  starSelected: {
    color: '#FFC107',
  },
  thankYou: {
    fontSize: 14,
    color: '#4CAF50',
    marginTop: 12,
  },
  doneButton: {
    position: 'absolute',
    bottom: 40,
    left: 24,
    right: 24,
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  doneButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  waitingMessage: {
    position: 'absolute',
    bottom: 40,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#E3F2FD',
    padding: 16,
    borderRadius: 8,
  },
  waitingIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  waitingText: {
    fontSize: 14,
    color: '#1976D2',
  },
});
