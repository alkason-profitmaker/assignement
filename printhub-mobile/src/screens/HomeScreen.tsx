/**
 * Home Screen - Main entry point with Print Now button
 */
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  RefreshControl,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/RootNavigator';
import { useAuth } from '../services/AuthContext';
import { ordersAPI, printerAPI } from '../services/api';

type HomeScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Home'>;
};

interface RecentOrder {
  order_number: string;
  status: string;
  total_pages: number;
  total_amount: number;
  created_at: string;
}

export default function HomeScreen({ navigation }: HomeScreenProps) {
  const { user, logout } = useAuth();
  const [recentOrders, setRecentOrders] = useState<RecentOrder[]>([]);
  const [stationStatus, setStationStatus] = useState<string>('checking...');
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      // Load recent orders
      const ordersResponse = await ordersAPI.getOrders(1, 3);
      setRecentOrders(ordersResponse.data.orders);

      // Load station status
      const stationResponse = await printerAPI.getStationInfo();
      setStationStatus(stationResponse.data.status);
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return '#4CAF50';
      case 'ready_to_print':
        return '#FF9800';
      case 'printing':
        return '#2196F3';
      case 'failed':
      case 'expired':
        return '#F44336';
      default:
        return '#999';
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Welcome Section */}
      <View style={styles.welcomeSection}>
        <Text style={styles.welcomeText}>
          Hello, {user?.name || 'User'}!
        </Text>
        <Text style={styles.flatInfo}>
          {user?.flat_number} {user?.tower && `• ${user.tower}`}
        </Text>
      </View>

      {/* Print Now Button */}
      <TouchableOpacity
        style={styles.printButton}
        onPress={() => navigation.navigate('FileUpload')}
      >
        <Text style={styles.printIcon}>🖨️</Text>
        <Text style={styles.printButtonText}>PRINT NOW</Text>
        <Text style={styles.printSubtext}>
          Station: {stationStatus === 'online' ? '✓ Online' : '⚠️ ' + stationStatus}
        </Text>
      </TouchableOpacity>

      {/* Pricing Info */}
      <View style={styles.pricingCard}>
        <Text style={styles.sectionTitle}>Pricing</Text>
        <View style={styles.priceRow}>
          <Text style={styles.priceLabel}>B/W Print</Text>
          <Text style={styles.priceValue}>₹3/page</Text>
        </View>
        <View style={styles.priceRow}>
          <Text style={styles.priceLabel}>Color Print</Text>
          <Text style={styles.priceValue}>₹10/page</Text>
        </View>
      </View>

      {/* Recent Orders */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Recent Orders</Text>
          <TouchableOpacity onPress={() => navigation.navigate('OrderHistory')}>
            <Text style={styles.viewAllLink}>View All</Text>
          </TouchableOpacity>
        </View>

        {recentOrders.length > 0 ? (
          recentOrders.map((order) => (
            <TouchableOpacity
              key={order.order_number}
              style={styles.orderCard}
              onPress={() => {
                if (order.status === 'ready_to_print') {
                  navigation.navigate('QRScanner', { orderNumber: order.order_number });
                } else if (order.status === 'printing') {
                  navigation.navigate('PrintStatus', { orderNumber: order.order_number });
                }
              }}
            >
              <View style={styles.orderInfo}>
                <Text style={styles.orderNumber}>#{order.order_number}</Text>
                <Text style={styles.orderDate}>{formatDate(order.created_at)}</Text>
              </View>
              <View style={styles.orderDetails}>
                <Text style={styles.orderPages}>{order.total_pages} pages</Text>
                <View style={[styles.statusBadge, { backgroundColor: getStatusColor(order.status) }]}>
                  <Text style={styles.statusText}>{order.status.replace('_', ' ')}</Text>
                </View>
              </View>
            </TouchableOpacity>
          ))
        ) : (
          <Text style={styles.noOrders}>No recent orders</Text>
        )}
      </View>

      {/* Quick Links */}
      <View style={styles.quickLinks}>
        <TouchableOpacity
          style={styles.quickLink}
          onPress={() => navigation.navigate('OrderHistory')}
        >
          <Text style={styles.quickLinkIcon}>📋</Text>
          <Text style={styles.quickLinkText}>Orders</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.quickLink}
          onPress={() => navigation.navigate('Profile')}
        >
          <Text style={styles.quickLinkIcon}>👤</Text>
          <Text style={styles.quickLinkText}>Profile</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.quickLink} onPress={logout}>
          <Text style={styles.quickLinkIcon}>🚪</Text>
          <Text style={styles.quickLinkText}>Logout</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  welcomeSection: {
    backgroundColor: '#2196F3',
    padding: 20,
    paddingTop: 10,
  },
  welcomeText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  flatInfo: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.8)',
    marginTop: 4,
  },
  printButton: {
    backgroundColor: '#fff',
    margin: 16,
    padding: 24,
    borderRadius: 16,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  printIcon: {
    fontSize: 48,
    marginBottom: 8,
  },
  printButtonText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  printSubtext: {
    fontSize: 14,
    color: '#666',
    marginTop: 8,
  },
  pricingCard: {
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginBottom: 16,
    padding: 16,
    borderRadius: 12,
  },
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  priceLabel: {
    fontSize: 16,
    color: '#666',
  },
  priceValue: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  section: {
    marginHorizontal: 16,
    marginBottom: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  viewAllLink: {
    fontSize: 14,
    color: '#2196F3',
  },
  orderCard: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 8,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  orderInfo: {},
  orderNumber: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  orderDate: {
    fontSize: 12,
    color: '#999',
    marginTop: 2,
  },
  orderDetails: {
    alignItems: 'flex-end',
  },
  orderPages: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  statusText: {
    fontSize: 12,
    color: '#fff',
    fontWeight: '600',
    textTransform: 'capitalize',
  },
  noOrders: {
    textAlign: 'center',
    color: '#999',
    paddingVertical: 20,
  },
  quickLinks: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 20,
    marginBottom: 20,
  },
  quickLink: {
    alignItems: 'center',
  },
  quickLinkIcon: {
    fontSize: 24,
    marginBottom: 4,
  },
  quickLinkText: {
    fontSize: 12,
    color: '#666',
  },
});
