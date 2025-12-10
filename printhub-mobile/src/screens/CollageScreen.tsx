/**
 * Collage Screen - Create photo collage from multiple images
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
  ScrollView,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/RootNavigator';

type CollageScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Collage'>;
  route: RouteProp<RootStackParamList, 'Collage'>;
};

type LayoutType = '2x1' | '2x2' | '3x2' | '4x2';

const LAYOUTS: { key: LayoutType; label: string; images: number }[] = [
  { key: '2x1', label: '2 Photos', images: 2 },
  { key: '2x2', label: '4 Photos', images: 4 },
  { key: '3x2', label: '6 Photos', images: 6 },
  { key: '4x2', label: '8 Photos', images: 8 },
];

export default function CollageScreen({ navigation, route }: CollageScreenProps) {
  const { images } = route.params;
  const [selectedLayout, setSelectedLayout] = useState<LayoutType>('2x2');

  const getLayoutConfig = (layout: LayoutType) => {
    switch (layout) {
      case '2x1':
        return { rows: 2, cols: 1 };
      case '2x2':
        return { rows: 2, cols: 2 };
      case '3x2':
        return { rows: 3, cols: 2 };
      case '4x2':
        return { rows: 4, cols: 2 };
      default:
        return { rows: 2, cols: 2 };
    }
  };

  const renderCollagePreview = () => {
    const config = getLayoutConfig(selectedLayout);
    const layoutImages = LAYOUTS.find((l) => l.key === selectedLayout)!.images;
    const previewImages = images.slice(0, layoutImages);

    const rows = [];
    let imageIndex = 0;

    for (let r = 0; r < config.rows; r++) {
      const rowImages = [];
      for (let c = 0; c < config.cols; c++) {
        if (imageIndex < previewImages.length) {
          rowImages.push(
            <Image
              key={`${r}-${c}`}
              source={{ uri: previewImages[imageIndex] }}
              style={[
                styles.previewImage,
                { width: `${100 / config.cols - 2}%` as any },
              ]}
            />
          );
          imageIndex++;
        } else {
          rowImages.push(
            <View
              key={`${r}-${c}`}
              style={[
                styles.emptySlot,
                { width: `${100 / config.cols - 2}%` as any },
              ]}
            >
              <Text style={styles.emptySlotText}>+</Text>
            </View>
          );
        }
      }
      rows.push(
        <View key={r} style={styles.previewRow}>
          {rowImages}
        </View>
      );
    }

    return rows;
  };

  const handleContinue = () => {
    const layoutConfig = LAYOUTS.find((l) => l.key === selectedLayout)!;
    const collageImages = images.slice(0, layoutConfig.images);

    navigation.navigate('Preview', {
      files: collageImages.map((uri, index) => ({
        uri,
        name: `image_${index}.jpg`,
        type: 'image',
      })),
      collageConfig: {
        layout: selectedLayout,
        create_collage: true,
      },
    });
  };

  const getPageCount = () => {
    const layoutConfig = LAYOUTS.find((l) => l.key === selectedLayout)!;
    const imagesPerPage = layoutConfig.images;
    return Math.ceil(images.length / imagesPerPage);
  };

  return (
    <View style={styles.container}>
      {/* Layout Selector */}
      <View style={styles.layoutSection}>
        <Text style={styles.sectionTitle}>Select Layout</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={styles.layoutOptions}>
            {LAYOUTS.map((layout) => (
              <TouchableOpacity
                key={layout.key}
                style={[
                  styles.layoutOption,
                  selectedLayout === layout.key && styles.layoutOptionSelected,
                ]}
                onPress={() => setSelectedLayout(layout.key)}
              >
                <View style={styles.layoutPreview}>
                  {layout.key === '2x1' && (
                    <View style={styles.miniLayout2x1}>
                      <View style={styles.miniCell} />
                      <View style={styles.miniCell} />
                    </View>
                  )}
                  {layout.key === '2x2' && (
                    <View style={styles.miniLayout2x2}>
                      <View style={styles.miniRow}>
                        <View style={styles.miniCell} />
                        <View style={styles.miniCell} />
                      </View>
                      <View style={styles.miniRow}>
                        <View style={styles.miniCell} />
                        <View style={styles.miniCell} />
                      </View>
                    </View>
                  )}
                  {layout.key === '3x2' && (
                    <View style={styles.miniLayout3x2}>
                      {[0, 1, 2].map((r) => (
                        <View key={r} style={styles.miniRow}>
                          <View style={styles.miniCell} />
                          <View style={styles.miniCell} />
                        </View>
                      ))}
                    </View>
                  )}
                  {layout.key === '4x2' && (
                    <View style={styles.miniLayout4x2}>
                      {[0, 1, 2, 3].map((r) => (
                        <View key={r} style={styles.miniRow}>
                          <View style={styles.miniCell} />
                          <View style={styles.miniCell} />
                        </View>
                      ))}
                    </View>
                  )}
                </View>
                <Text
                  style={[
                    styles.layoutLabel,
                    selectedLayout === layout.key && styles.layoutLabelSelected,
                  ]}
                >
                  {layout.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </ScrollView>
      </View>

      {/* Preview */}
      <View style={styles.previewSection}>
        <Text style={styles.sectionTitle}>Preview</Text>
        <View style={styles.previewContainer}>{renderCollagePreview()}</View>
        <Text style={styles.previewInfo}>
          {images.length} images selected • {getPageCount()} page(s)
        </Text>
      </View>

      {/* Continue Button */}
      <TouchableOpacity style={styles.continueButton} onPress={handleContinue}>
        <Text style={styles.continueButtonText}>Continue to Preview</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  layoutSection: {
    padding: 16,
    backgroundColor: '#fff',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  layoutOptions: {
    flexDirection: 'row',
    gap: 12,
  },
  layoutOption: {
    alignItems: 'center',
    padding: 12,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#ddd',
    backgroundColor: '#fff',
  },
  layoutOptionSelected: {
    borderColor: '#2196F3',
    backgroundColor: '#E3F2FD',
  },
  layoutPreview: {
    width: 60,
    height: 80,
    marginBottom: 8,
  },
  miniLayout2x1: {
    flex: 1,
    gap: 2,
  },
  miniLayout2x2: {
    flex: 1,
    gap: 2,
  },
  miniLayout3x2: {
    flex: 1,
    gap: 2,
  },
  miniLayout4x2: {
    flex: 1,
    gap: 1,
  },
  miniRow: {
    flex: 1,
    flexDirection: 'row',
    gap: 2,
  },
  miniCell: {
    flex: 1,
    backgroundColor: '#E0E0E0',
    borderRadius: 2,
  },
  layoutLabel: {
    fontSize: 12,
    color: '#666',
  },
  layoutLabelSelected: {
    color: '#2196F3',
    fontWeight: '600',
  },
  previewSection: {
    flex: 1,
    padding: 16,
  },
  previewContainer: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 8,
    aspectRatio: 0.707, // A4 aspect ratio
    gap: 4,
  },
  previewRow: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 4,
  },
  previewImage: {
    flex: 1,
    borderRadius: 4,
    backgroundColor: '#f0f0f0',
  },
  emptySlot: {
    flex: 1,
    borderRadius: 4,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#ddd',
    borderStyle: 'dashed',
  },
  emptySlotText: {
    fontSize: 24,
    color: '#ccc',
  },
  previewInfo: {
    textAlign: 'center',
    color: '#666',
    marginTop: 12,
  },
  continueButton: {
    backgroundColor: '#2196F3',
    margin: 16,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  continueButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});
