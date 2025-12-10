/**
 * Preview Screen - Show preview and pricing before payment
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/RootNavigator';
import { ordersAPI } from '../services/api';

type PreviewScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Preview'>;
  route: RouteProp<RootStackParamList, 'Preview'>;
};

interface PriceBreakdown {
  bw_pages: number;
  color_pages: number;
  bw_price_per_page: number;
  color_price_per_page: number;
  bw_total: number;
  color_total: number;
  total_amount: number;
}

interface OrderPreview {
  items: any[];
  price_breakdown: PriceBreakdown;
  station_location: string;
  validity_hours: number;
}

export default function PreviewScreen({ navigation, route }: PreviewScreenProps) {
  const { files, collageConfig } = route.params;
  const [isLoading, setIsLoading] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const [preview, setPreview] = useState<OrderPreview | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadPreview();
  }, []);

  const loadPreview = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Create form data for upload
      const formData = new FormData();
      files.forEach((file: any, index: number) => {
        formData.append('files', {
          uri: file.uri,
          name: file.name,
          type: file.type === 'pdf' ? 'application/pdf' : 'image/jpeg',
        } as any);
      });

      if (collageConfig) {
        formData.append('collage_config', JSON.stringify(collageConfig));
      }

      const response = await ordersAPI.uploadFiles(formData);
      setPreview(response.data);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to process files');
    } finally {
      setIsLoading(false);
    }
  };

  const handlePay = async () => {
    try {
      setIsCreating(true);

      // Create the order
      const formData = new FormData();
      files.forEach((file: any) => {
        formData.append('files', {
          uri: file.uri,
          name: file.name,
          type: file.type === 'pdf' ? 'application/pdf' : 'image/jpeg',
        } as any);
      });

      if (collageConfig) {
        formData.append('collage_config', JSON.stringify(collageConfig));
      }

      const response = await ordersAPI.createOrder(formData);
      const order = response.data;

      // Navigate to payment
      navigation.navigate('Payment', {
        orderId: order.id,
        orderNumber: order.order_number,
        amount: order.total_amount,
      });
    } catch (err: any) {
      Alert.alert('Error', err.response?.data?.detail || 'Failed to create order');
    } finally {
      setIsCreating(false);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Processing files...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorIcon}>⚠️</Text>
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={loadPreview}>
          <Text style={styles.retryButtonText}>Retry</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (!preview) return null;

  const { price_breakdown, station_location, validity_hours, items } = preview;

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Files Summary */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Files</Text>
          {items.map((item: any, index: number) => (
            <View key={index} style={styles.fileItem}>
              <View style={styles.fileIcon}>
                <Text>{item.is_collage ? '🖼️' : item.file_type === 'pdf' ? '📄' : '🖼️'}</Text>
              </View>
              <View style={styles.fileInfo}>
                <Text style={styles.fileName}>{item.file_name}</Text>
                <Text style={styles.filePages}>
                  {item.total_pages} page(s) • {item.bw_pages > 0 ? `${item.bw_pages} B/W` : ''}
                  {item.bw_pages > 0 && item.color_pages > 0 ? ' + ' : ''}
                  {item.color_pages > 0 ? `${item.color_pages} Color` : ''}
                </Text>
              </View>
              <Text style={styles.filePrice}>₹{item.item_amount}</Text>
            </View>
          ))}
        </View>

        {/* Price Breakdown */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Price Breakdown</Text>
          <View style={styles.priceCard}>
            {price_breakdown.bw_pages > 0 && (
              <View style={styles.priceRow}>
                <Text style={styles.priceLabel}>
                  B/W ({price_breakdown.bw_pages} pages × ₹{price_breakdown.bw_price_per_page})
                </Text>
                <Text style={styles.priceValue}>₹{price_breakdown.bw_total}</Text>
              </View>
            )}
            {price_breakdown.color_pages > 0 && (
              <View style={styles.priceRow}>
                <Text style={styles.priceLabel}>
                  Color ({price_breakdown.color_pages} pages × ₹{price_breakdown.color_price_per_page})
                </Text>
                <Text style={styles.priceValue}>₹{price_breakdown.color_total}</Text>
              </View>
            )}
            <View style={[styles.priceRow, styles.totalRow]}>
              <Text style={styles.totalLabel}>Total</Text>
              <Text style={styles.totalValue}>₹{price_breakdown.total_amount}</Text>
            </View>
          </View>
        </View>

        {/* Station Info */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Print Location</Text>
          <View style={styles.infoCard}>
            <Text style={styles.locationIcon}>📍</Text>
            <View>
              <Text style={styles.locationText}>{station_location}</Text>
              <Text style={styles.validityText}>
                Valid for {validity_hours} hours after payment
              </Text>
            </View>
          </View>
        </View>
      </ScrollView>

      {/* Pay Button */}
      <View style={styles.footer}>
        <View style={styles.footerPrice}>
          <Text style={styles.footerPriceLabel}>Total</Text>
          <Text style={styles.footerPriceValue}>₹{price_breakdown.total_amount}</Text>
        </View>
        <TouchableOpacity
          style={[styles.payButton, isCreating && styles.payButtonDisabled]}
          onPress={handlePay}
          disabled={isCreating}
        >
          <Text style={styles.payButtonText}>
            {isCreating ? 'Creating Order...' : `Pay ₹${price_breakdown.total_amount}`}
          </Text>
        </TouchableOpacity>
      </View>
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
    fontSize: 16,
    color: '#666',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  errorIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    textAlign: 'center',
    marginBottom: 24,
  },
  retryButton: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  scrollView: {
    flex: 1,
  },
  section: {
    backgroundColor: '#fff',
    marginBottom: 12,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  fileItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  fileIcon: {
    width: 40,
    height: 40,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fileInfo: {
    flex: 1,
    marginLeft: 12,
  },
  fileName: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  filePages: {
    fontSize: 12,
    color: '#999',
    marginTop: 2,
  },
  filePrice: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  priceCard: {
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
    padding: 16,
  },
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  priceLabel: {
    fontSize: 14,
    color: '#666',
  },
  priceValue: {
    fontSize: 14,
    color: '#333',
  },
  totalRow: {
    borderTopWidth: 1,
    borderTopColor: '#ddd',
    marginTop: 8,
    paddingTop: 12,
  },
  totalLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  totalValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  infoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#E3F2FD',
    borderRadius: 8,
    padding: 16,
  },
  locationIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  locationText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  validityText: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: '#eee',
  },
  footerPrice: {
    marginRight: 16,
  },
  footerPriceLabel: {
    fontSize: 12,
    color: '#999',
  },
  footerPriceValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  payButton: {
    flex: 1,
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  payButtonDisabled: {
    backgroundColor: '#90CAF9',
  },
  payButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});
