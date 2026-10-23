import { Remote, RemoteInfo } from "./config.js";

//#region src/type/preload.d.ts
type depsPreloadArg = Omit<PreloadRemoteArgs, 'depsRemote'>;
interface PreloadRemoteArgs {
  nameOrAlias: string;
  exposes?: Array<string>;
  resourceCategory?: 'all' | 'sync';
  share?: boolean;
  depsRemote?: boolean | Array<depsPreloadArg>;
  filter?: (assetUrl: string) => boolean;
}
type PreloadConfig = PreloadRemoteArgs;
type PreloadOptions = Array<{
  remote: Remote;
  preloadConfig: PreloadConfig;
}>;
type ResourceLoadInitiator = 'loadRemote' | 'preloadRemote';
type ResourceLoadType = 'manifest' | 'remoteEntry' | 'js' | 'css';
interface ResourceLoadContext {
  initiator: ResourceLoadInitiator;
  id: string;
  resourceType: ResourceLoadType;
  url?: string;
}
type PreloadAssetStatus = 'success' | 'error' | 'timeout' | 'cached';
interface PreloadAssetResult {
  url: string;
  status: PreloadAssetStatus;
  resourceType: ResourceLoadType;
  initiator: ResourceLoadInitiator;
  id: string;
  error?: unknown;
}
interface PreloadRemoteResult {
  remote: Remote;
  remoteInfo: RemoteInfo;
  preloadConfig: PreloadConfig;
  id: string;
  results: PreloadAssetResult[];
}
type EntryAssets = {
  name: string;
  url: string;
  moduleInfo: RemoteInfo;
};
interface PreloadAssets {
  cssAssets: Array<string>;
  jsAssetsWithoutEntry: Array<string>;
  entryAssets: Array<EntryAssets>;
}
//#endregion
export { EntryAssets, PreloadAssetResult, PreloadAssetStatus, PreloadAssets, PreloadConfig, PreloadOptions, PreloadRemoteArgs, PreloadRemoteResult, ResourceLoadContext, ResourceLoadInitiator, ResourceLoadType, depsPreloadArg };
//# sourceMappingURL=preload.d.ts.map