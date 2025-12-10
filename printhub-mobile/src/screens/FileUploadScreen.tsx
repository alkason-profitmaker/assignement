/**
 * File Upload Screen - Select files for printing
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  FlatList,
  Image,
  Alert,
} from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/RootNavigator';

type FileUploadScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'FileUpload'>;
};

interface SelectedFile {
  uri: string;
  name: string;
  type: string;
  size?: number;
}

export default function FileUploadScreen({ navigation }: FileUploadScreenProps) {
  const [selectedFiles, setSelectedFiles] = useState<SelectedFile[]>([]);

  const pickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: 'application/pdf',
        multiple: true,
        copyToCacheDirectory: true,
      });

      if (result.canceled) return;

      const newFiles = result.assets.map((asset) => ({
        uri: asset.uri,
        name: asset.name,
        type: 'pdf',
        size: asset.size,
      }));

      setSelectedFiles([...selectedFiles, ...newFiles]);
    } catch (error) {
      Alert.alert('Error', 'Failed to pick document');
    }
  };

  const pickImages = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Please allow access to your photos');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsMultipleSelection: true,
        quality: 1,
      });

      if (result.canceled) return;

      const newFiles = result.assets.map((asset, index) => ({
        uri: asset.uri,
        name: asset.fileName || `image_${Date.now()}_${index}.jpg`,
        type: 'image',
        size: asset.fileSize,
      }));

      setSelectedFiles([...selectedFiles, ...newFiles]);
    } catch (error) {
      Alert.alert('Error', 'Failed to pick images');
    }
  };

  const removeFile = (index: number) => {
    const newFiles = [...selectedFiles];
    newFiles.splice(index, 1);
    setSelectedFiles(newFiles);
  };

  const handleContinue = () => {
    if (selectedFiles.length === 0) {
      Alert.alert('No Files', 'Please select at least one file');
      return;
    }

    // Check if all are images for collage option
    const allImages = selectedFiles.every((f) => f.type === 'image');

    if (allImages && selectedFiles.length > 1) {
      // Offer collage option
      Alert.alert(
        'Create Collage?',
        'You have selected multiple images. Would you like to create a photo collage?',
        [
          {
            text: 'No, Print Separately',
            onPress: () => navigation.navigate('Preview', { files: selectedFiles }),
          },
          {
            text: 'Yes, Create Collage',
            onPress: () =>
              navigation.navigate('Collage', {
                images: selectedFiles.map((f) => f.uri),
              }),
          },
        ]
      );
    } else {
      navigation.navigate('Preview', { files: selectedFiles });
    }
  };

  const renderFileItem = ({ item, index }: { item: SelectedFile; index: number }) => (
    <View style={styles.fileItem}>
      {item.type === 'image' ? (
        <Image source={{ uri: item.uri }} style={styles.thumbnail} />
      ) : (
        <View style={styles.pdfIcon}>
          <Text style={styles.pdfIconText}>PDF</Text>
        </View>
      )}
      <View style={styles.fileInfo}>
        <Text style={styles.fileName} numberOfLines={1}>
          {item.name}
        </Text>
        {item.size && (
          <Text style={styles.fileSize}>
            {(item.size / 1024).toFixed(1)} KB
          </Text>
        )}
      </View>
      <TouchableOpacity
        style={styles.removeButton}
        onPress={() => removeFile(index)}
      >
        <Text style={styles.removeButtonText}>✕</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      {/* Upload Options */}
      <View style={styles.uploadOptions}>
        <TouchableOpacity style={styles.uploadButton} onPress={pickDocument}>
          <Text style={styles.uploadIcon}>📄</Text>
          <Text style={styles.uploadText}>Select PDF</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.uploadButton} onPress={pickImages}>
          <Text style={styles.uploadIcon}>🖼️</Text>
          <Text style={styles.uploadText}>Select Images</Text>
        </TouchableOpacity>
      </View>

      {/* Selected Files */}
      <View style={styles.filesSection}>
        <Text style={styles.sectionTitle}>
          Selected Files ({selectedFiles.length})
        </Text>

        {selectedFiles.length > 0 ? (
          <FlatList
            data={selectedFiles}
            renderItem={renderFileItem}
            keyExtractor={(item, index) => `${item.uri}-${index}`}
            style={styles.fileList}
          />
        ) : (
          <View style={styles.emptyState}>
            <Text style={styles.emptyIcon}>📁</Text>
            <Text style={styles.emptyText}>No files selected</Text>
            <Text style={styles.emptySubtext}>
              Select PDFs or images to print
            </Text>
          </View>
        )}
      </View>

      {/* Continue Button */}
      <TouchableOpacity
        style={[
          styles.continueButton,
          selectedFiles.length === 0 && styles.continueButtonDisabled,
        ]}
        onPress={handleContinue}
        disabled={selectedFiles.length === 0}
      >
        <Text style={styles.continueButtonText}>Continue</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  uploadOptions: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
  },
  uploadButton: {
    flex: 1,
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#2196F3',
    borderStyle: 'dashed',
  },
  uploadIcon: {
    fontSize: 32,
    marginBottom: 8,
  },
  uploadText: {
    fontSize: 14,
    color: '#2196F3',
    fontWeight: '600',
  },
  filesSection: {
    flex: 1,
    paddingHorizontal: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  fileList: {
    flex: 1,
  },
  fileItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  thumbnail: {
    width: 48,
    height: 48,
    borderRadius: 4,
  },
  pdfIcon: {
    width: 48,
    height: 48,
    borderRadius: 4,
    backgroundColor: '#F44336',
    justifyContent: 'center',
    alignItems: 'center',
  },
  pdfIconText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
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
  fileSize: {
    fontSize: 12,
    color: '#999',
    marginTop: 2,
  },
  removeButton: {
    padding: 8,
  },
  removeButtonText: {
    fontSize: 18,
    color: '#999',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  emptyText: {
    fontSize: 18,
    color: '#333',
    fontWeight: '600',
  },
  emptySubtext: {
    fontSize: 14,
    color: '#999',
    marginTop: 4,
  },
  continueButton: {
    backgroundColor: '#2196F3',
    margin: 16,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  continueButtonDisabled: {
    backgroundColor: '#ccc',
  },
  continueButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});
