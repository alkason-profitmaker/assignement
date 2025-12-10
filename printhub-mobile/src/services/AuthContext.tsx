/**
 * Authentication Context for PrintHub
 * Manages user authentication state across the app
 */
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { authAPI, setAuthToken, getAuthToken, clearAuthToken } from './api';

// User type
interface User {
  id: number;
  phone_number: string;
  name?: string;
  flat_number?: string;
  tower?: string;
  society_id: string;
  is_verified: boolean;
}

// Auth context type
interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (phoneNumber: string) => Promise<{ success: boolean; message: string }>;
  verifyOTP: (phoneNumber: string, otp: string) => Promise<{ success: boolean; message: string }>;
  logout: () => Promise<void>;
  updateUser: (data: Partial<User>) => Promise<void>;
}

// Create context
const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Provider component
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Check for existing session on mount
  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const token = await getAuthToken();
      if (token) {
        const response = await authAPI.getProfile();
        setUser(response.data);
      }
    } catch (error) {
      // Token invalid or expired
      await clearAuthToken();
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (phoneNumber: string) => {
    try {
      const response = await authAPI.login(phoneNumber);
      return {
        success: response.data.success,
        message: response.data.message || 'OTP sent successfully',
      };
    } catch (error: any) {
      return {
        success: false,
        message: error.response?.data?.detail || 'Failed to send OTP',
      };
    }
  };

  const verifyOTP = async (phoneNumber: string, otp: string) => {
    try {
      const response = await authAPI.verifyOTP(phoneNumber, otp);
      const { access_token, user: userData } = response.data;

      await setAuthToken(access_token);
      setUser(userData);

      return {
        success: true,
        message: 'Login successful',
      };
    } catch (error: any) {
      return {
        success: false,
        message: error.response?.data?.detail || 'Invalid OTP',
      };
    }
  };

  const logout = async () => {
    await clearAuthToken();
    setUser(null);
  };

  const updateUser = async (data: Partial<User>) => {
    try {
      const response = await authAPI.updateProfile(data);
      setUser(response.data);
    } catch (error) {
      throw error;
    }
  };

  const value: AuthContextType = {
    user,
    isLoading,
    isAuthenticated: !!user,
    login,
    verifyOTP,
    logout,
    updateUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// Custom hook to use auth context
export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export default AuthContext;
