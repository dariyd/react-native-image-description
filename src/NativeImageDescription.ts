import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  classifyImage(imageUri: string, options: Object): Promise<Object>;
  describeImage(imageUri: string, options: Object): Promise<Object>;
  checkDescriptionModelStatus(): Promise<string>;
  downloadDescriptionModel(): Promise<boolean>;
  isAvailable(): Promise<boolean>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ImageDescription');

