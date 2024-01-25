/**
 * File: storage.ts
 * 
 * Description: 
 *  This file contains the implementation of the StorageClient class 
 *  This class is used to provide an access to Azure Storage Account
 * 
 */

import { ContainerClient, BlobServiceClient, BlockBlobClient, BlobUploadCommonResponse, BlockBlobUploadResponse, ContainerCreateIfNotExistsResponse } from "@azure/storage-blob";
import { InteractiveBrowserCredential } from "@azure/identity";
import { isNullOrUndefinedOrEmpty } from "./common";
import { LogClient } from "./logclient";

export interface ProgressCallback {
  (file: string, folder: string, progress: number): void;
}
export interface CompletedCallback {
  (file: string, folder: string, errorCode: string | undefined): void;
}

export class StorageClient {
  logClient: LogClient;
  accountName: string;
  containerName: string;
  sasToken: string;
  clientId: string;
  tenantId: string;
  redirectUri: string;

  constructor(logClient: LogClient, account: string, container: string, token: string, clientId: string, tenantId: string, redirectUri: string) {
    this.logClient = logClient;
    this.accountName = account;
    this.containerName = container;
    this.sasToken = token;
    this.clientId = clientId;
    this.tenantId = tenantId;
    this.redirectUri = redirectUri;
  }

  // return list of blobs in container to display
  async getBlobsInContainer(containerClient: ContainerClient) {
    const returnedBlobUrls: string[] = [];

    // get list of blobs in container
    // eslint-disable-next-line
    for await (const blob of containerClient.listBlobsFlat()) {
      // if image is public, just construct URL
      returnedBlobUrls.push(
        `https://${this.accountName}.blob.core.windows.net/${this.containerName}/${blob.name}`
      );
    }

    return returnedBlobUrls;
  }

  async createBlobTextInContainer(containerClient: ContainerClient, path: string, content: string): Promise<BlockBlobUploadResponse> {
    // create blobClient for container
    const blobClient = containerClient.getBlockBlobClient(path);
    return blobClient.upload(content, content.length);
  }


  createBlobInContainer(containerClient: ContainerClient, file: File): Promise<BlobUploadCommonResponse> {
    // create blobClient for container
    const blobClient = containerClient.getBlockBlobClient(file.name);
    // set mimetype as determined from browser with file upload control
    const options = { blobHTTPHeaders: { blobContentType: file.type } };
    // upload file
    return blobClient.uploadData(file, options);
  }

  getErrorMessage(error: unknown) {
    if (error instanceof Error) return error.message
    return String(error)
  }
  getStoragePath(file: string, folder: string): string {
    if ((folder) && (folder.length > 0)) {
      if (folder.endsWith("/"))
        return `${folder}${file}`;
      return `${folder}/${file}`;
    }
    return file;
  }
  getStorageUri(file: string, folder: string): string {
    if ((folder) && (folder.length > 0)) {
      if (folder.endsWith("/"))
        return `https://${this.accountName}.blob.core.windows.net/${this.containerName}/${folder}${file}`;
      else
        return `https://${this.accountName}.blob.core.windows.net/${this.containerName}/${folder}/${file}`;
    }
    return `https://${this.accountName}.blob.core.windows.net/${this.containerName}/${file}`;
  }
  getBlobClient(container: ContainerClient, file: string, folder: string): BlockBlobClient {
    // create blobClient for container    
    return container.getBlockBlobClient(this.getStoragePath(file, folder));
  }

  getContainerClient(): Promise<ContainerClient> {
    return new Promise<ContainerClient>((resolve, reject) => {
      (async () => {
        try {
          let blobService = null;
          if (isNullOrUndefinedOrEmpty(this.sasToken)) {
            const signInOptions = {
              clientId: this.clientId,
              tenantId: this.tenantId,
              redirectUri: this.redirectUri
            }
            // if Azure Web Site assume Managed Identity 
            if (window.location.host.includes("azurewebsites.net"))
              blobService = new BlobServiceClient(
                `https://${this.accountName}.blob.core.windows.net/`,
                new InteractiveBrowserCredential(signInOptions)
                //new DefaultAzureCredential()
              );
            else
              // else single page no managed identity
              blobService = new BlobServiceClient(
                `https://${this.accountName}.blob.core.windows.net/`,
                new InteractiveBrowserCredential(signInOptions)
              );
          }
          else {
            // get BlobService = notice `?` is pulled out of sasToken - if created in Azure portal
            blobService = new BlobServiceClient(
              `https://${this.accountName}.blob.core.windows.net/?${this.sasToken}`
            );
          }

          // get Container - full public read access
          const containerClient: ContainerClient = blobService.getContainerClient(this.containerName);
          const response: ContainerCreateIfNotExistsResponse = await containerClient.createIfNotExists({
            access: 'container',
          });
          if (response.succeeded == true) {
            this.logClient.log(`Container ${this.containerName} has been created`);
          }
          else {
            this.logClient.log(`Container ${this.containerName} already created`);
          }

          resolve(containerClient);
        }
        catch (error) {
          this.logClient.log(`Exception while getting ContainerClient:  ${error}`);
          reject(error);
        }
      })();
    });
  }
  async uploadFileWithProgessAsync(
    blobClient: BlockBlobClient,
    file: File,
    folder: string,
    progressCallback: ProgressCallback): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          // upload file
          const response: BlobUploadCommonResponse = await blobClient.uploadBrowserData(file, {
            blockSize: 4 * 1024 * 1024, // 4MB block size
            concurrency: 20, // 20 concurrency
            onProgress: (ev) => {
              this.logClient.log(`${ev.loadedBytes} bytes prepared for upload`);
              const progress = (ev.loadedBytes / file.size) * 100;
              progressCallback(file.name, folder, progress);
            },
            blobHTTPHeaders: { blobContentType: file.type }
          })
          if (response) {
            if (response.errorCode) {
              progressCallback(file.name, folder, 0);
              reject(this.getErrorMessage(response.errorCode));
            }
            else {
              progressCallback(file.name, folder, 100);
              this.logClient.log(`File ${file.name} successfully uploaded`);
              resolve(true);
            }
          }
          else {
            const error = "Internal Error: response null while launching the upload";
            progressCallback(file.name, folder, 0);
            this.logClient.error(error);
            reject(error);
          }
        }
        catch (error) {
          progressCallback(file.name, folder, 0);
          this.logClient.error(error);
          reject(error);
        }
      })();
    });
  }
  async uploadFilesWithProgessAsync(
    files: FileList,
    folder: string,
    progressCallback: ProgressCallback): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          const containerClient = await this.getContainerClient();
          if (containerClient) {
            if (files) {
              for (let i = 0; i < files.length; i++) {
                let result = false;
                const blobClient: BlockBlobClient = this.getBlobClient(containerClient, files[i].name, folder);
                if (blobClient) {
                  result = await this.uploadFileWithProgessAsync(blobClient, files[i], folder, progressCallback);
                  if (result) {
                    const message = `File ${files[i].name} size: ${files[i].size} bytes uploaded`;
                    this.logClient.log(message);
                  }
                  else {
                    const error = `Error while uploading File ${files[i].name} size: ${files[i].size} bytes`;
                    this.logClient.error(error);
                    reject(error);
                  }
                }
                else {
                  const error = `Error while uploading File ${files[i].name} size: ${files[i].size} bytes: BlobClient null`;
                  this.logClient.error(error);
                  reject(error);
                }
              }
            }
            resolve(true);
          }
          else {
            const error = `Error while uploading Files: Container null`;
            this.logClient.error(error);
            reject(error);
          }
        }
        catch (e) {
          const error = `Exception while uploading Files: ${e}`;
          this.logClient.error(error);
          reject(error);
        }
      })();
    });
  }

  createBlobInContainerWithProgess(containerClient: ContainerClient,
    file: File,
    folder: string,
    progressCallback: ProgressCallback,
    completedCallback: CompletedCallback): boolean {

    // create blobClient for container    
    const blobClient = containerClient.getBlockBlobClient(this.getStoragePath(file.name, folder));

    // upload file
    try {
      blobClient.uploadBrowserData(file, {
        blockSize: 4 * 1024 * 1024, // 4MB block size
        concurrency: 20, // 20 concurrency
        onProgress: (ev) => {
          this.logClient.log(`${ev.loadedBytes} bytes prepared for upload`);
          const progress = (ev.loadedBytes / file.size) * 100;
          progressCallback(file.name, folder, progress);
        },
        blobHTTPHeaders: { blobContentType: file.type }
      }).then(response => {
        this.logClient.log(response);
        completedCallback(file.name, folder, response.errorCode);
      })
        .catch((error) => {
          this.logClient.error(error);
          progressCallback(file.name, folder, 0);
          this.logClient.error(this.getErrorMessage(error))
          completedCallback(file.name, folder, this.getErrorMessage(error));
        })
      return true;
    }
    catch (e) {
      progressCallback(file.name, folder, 0);
      this.logClient.error(this.getErrorMessage(e))
      completedCallback(file.name, folder, this.getErrorMessage(e));
    }
    return false;
  }

  async uploadFileToBlob(file: File | null): Promise<BlobUploadCommonResponse | null> {
    if (!file) return null;

    let blobService = null;
    if (isNullOrUndefinedOrEmpty(this.sasToken)) {
      const signInOptions = {
        clientId: this.clientId,
        tenantId: this.tenantId,
        redirectUri: this.redirectUri
      }
      // if Azure Web Site assume Managed Identity 
      if (window.location.host.includes("azurewebsites.net"))
        blobService = new BlobServiceClient(
          `https://${this.accountName}.blob.core.windows.net/`,
          new InteractiveBrowserCredential(signInOptions)
          //new DefaultAzureCredential()
        );
      else
        // else single page no managed identity
        blobService = new BlobServiceClient(
          `https://${this.accountName}.blob.core.windows.net/`,
          new InteractiveBrowserCredential(signInOptions)
        );
    }
    else {
      // get BlobService = notice `?` is pulled out of sasToken - if created in Azure portal
      blobService = new BlobServiceClient(
        `https://${this.accountName}.blob.core.windows.net/?${this.sasToken}`
      );
    }

    // get Container - full public read access
    const containerClient: ContainerClient = blobService.getContainerClient(this.containerName);
    await containerClient.createIfNotExists({
      access: 'container',
    });

    // upload file
    return this.createBlobInContainer(containerClient, file);
  }

  async uploadFileToBlobWithProgess(file: File | null, folder: string, progressCallback: ProgressCallback, completedCallback: CompletedCallback): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          let blobService = null;
          if (isNullOrUndefinedOrEmpty(this.sasToken)) {
            const signInOptions = {
              clientId: this.clientId,
              tenantId: this.tenantId
            }
            // if Azure Web Site assume Managed Identity 
            if (window.location.host.includes("azurewebsites.net"))
              blobService = new BlobServiceClient(
                `https://${this.accountName}.blob.core.windows.net/`,
                //new DefaultAzureCredential()
                new InteractiveBrowserCredential(signInOptions)
              );
            else
              // else single page no managed identity
              blobService = new BlobServiceClient(
                `https://${this.accountName}.blob.core.windows.net/`,
                new InteractiveBrowserCredential(signInOptions)
              );
          }
          else {
            // get BlobService = notice `?` is pulled out of sasToken - if created in Azure portal
            blobService = new BlobServiceClient(
              `https://${this.accountName}.blob.core.windows.net/?${this.sasToken}`
            );
          }

          // get Container - full public read access
          const containerClient: ContainerClient = blobService.getContainerClient(this.containerName);
          await containerClient.createIfNotExists({
            access: 'container',
          });
          if (file) {
            // upload file
            const result = this.createBlobInContainerWithProgess(containerClient, file, folder,
              progressCallback,
              (file: string, folder: string, error: string | undefined) => {
                completedCallback(file, folder, error);
                if (error) {
                  reject(error);
                }
                else {
                  resolve(true);
                }
              });
            if (result == true)
              resolve(true);
            else
              reject("Error while launching the upload");
          }
          else
            reject("file null");
        }
        catch (error) {
          reject(error);
        }
      })();
    });

  }

  async uploadTextToBlob(path: string, content: string): Promise<BlockBlobUploadResponse | null> {
    if (!path)
      return null;
    if (!content)
      return null;


    // get BlobService = notice `?` is pulled out of sasToken - if created in Azure portal
    const blobService = new BlobServiceClient(
      `https://${this.accountName}.blob.core.windows.net/?${this.sasToken}`
    );

    // get Container - full public read access
    const containerClient: ContainerClient = blobService.getContainerClient(this.containerName);
    await containerClient.createIfNotExists({
      access: 'container',
    });

    // upload file
    return this.createBlobTextInContainer(containerClient, path, content);
  }
}
