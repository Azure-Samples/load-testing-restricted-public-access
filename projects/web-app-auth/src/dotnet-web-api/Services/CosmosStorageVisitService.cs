using Azure;
using Microsoft.Azure.Cosmos;
using dotnet_web_api.Models;
using System.Net;
using System.Runtime.CompilerServices;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Implementation of Table Storage Visit Service 
    /// </summary>        
    public class CosmosStorageVisitService : ITableStorageVisitService
    {
        private const string PartitionKey = "visit";

        private readonly Container _tableClient;
        private readonly ILogger<CosmosStorageVisitService> _logger;

        public CosmosStorageVisitService(ICosmosClientFactory clientFactory, ILogger<CosmosStorageVisitService> logger)
        {
            _ = clientFactory ?? throw new ArgumentNullException(nameof(clientFactory));
            _tableClient = clientFactory.CreateClient(nameof(ITableStorageVisitService)) ?? throw new ArgumentException("No table client");

            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }


        /// <summary>
        /// Get list of all Visits
        /// </summary>
        /// <returns>List<Visit></returns>        

        public async Task<List<Visit>?> RetrieveAllVisitAsync()
        {
            try
            {
                var list = new List<Visit>();
                FeedIterator<VisitEntity> feedIterator = _tableClient.GetItemQueryIterator<VisitEntity>("SELECT * FROM c");
                while (feedIterator.HasMoreResults)
                {
                    FeedResponse<VisitEntity> res = await feedIterator.ReadNextAsync();
                    foreach (VisitEntity ent in res)
                    {
                        if (ent.RowKey != null)
                        {
                            var entity = new Visit
                            {
                                id = ent.RowKey,
                                user = ent.user,
                                information = ent.information,
                                localIp = ent.localIp,
                                localPort = ent.localPort,
                                remoteIp = ent.remoteIp,
                                remotePort = ent.remotePort,
                                creationDate = ent.creationDate
                            };

                            list.Add(entity);
                        }
                    }
                }
                return list;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception thrown");
                return null;
            }
        }

        /// <summary>
        /// Get a Visit by id
        /// </summary>
        /// <param name="id">Visit id to retrieve</param>
        /// <returns>Visit</returns>        
        public async Task<Visit?> RetrieveVisitAsync(string id)
        {
            try
            {
                ItemResponse<VisitEntity> response = await _tableClient.ReadItemAsync<VisitEntity>(id, new PartitionKey(CosmosStorageVisitService.PartitionKey));
                if (response.StatusCode == HttpStatusCode.OK)
                {
                    VisitEntity ent = response.Resource;
                    if (ent != null)
                    {
                        if (ent.RowKey != null)
                        {
                            var entity = new Visit
                            {
                                id = ent.RowKey,
                                user = ent.user,
                                information = ent.information,
                                localIp = ent.localIp,
                                localPort = ent.localPort,
                                remoteIp = ent.remoteIp,
                                remotePort = ent.remotePort,
                                creationDate = ent.creationDate
                            };
                            return entity;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception thrown");
            }

            return null;

        }

        /// <summary>
        /// Create a new Visit 
        /// </summary>
        /// <param name="entity">new Visit</param>
        /// <returns>Visit</returns>        
        public async Task<Visit?> InsertVisitAsync(Visit entity)
        {
            if (entity == null || entity.id == null || string.IsNullOrEmpty(entity.id))
                return null;

            var entdb = new VisitEntity
            {
                user = entity.user,
                information = entity.information,
                localIp = entity.localIp,
                localPort = entity.localPort,
                remoteIp = entity.remoteIp,
                remotePort = entity.remotePort,
                creationDate = entity.creationDate,
                PartitionKey = PartitionKey,
                RowKey = entity.id
            };

            try
            {
                HttpStatusCode code = (await _tableClient.UpsertItemAsync<VisitEntity>(entdb)).StatusCode;
                return (code == HttpStatusCode.Created)
                    ? await RetrieveVisitAsync(entity.id)
                    : null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception thrown");
            }

            return null;
        }

        /// <summary>
        /// Update a Visit 
        /// </summary>
        /// <param name="entity">updated Visit</param>
        /// <returns>Visit</returns>        
        public async Task<Visit?> UpdateVisitAsync(Visit entity)
        {
            if (entity == null || entity.id == null || string.IsNullOrEmpty(entity.id))
                return null;

            var entdb = new VisitEntity
            {
                user = entity.user,
                information = entity.information,
                localIp = entity.localIp,
                localPort = entity.localPort,
                remoteIp = entity.remoteIp,
                remotePort = entity.remotePort,
                creationDate = entity.creationDate,
                PartitionKey = PartitionKey,
                RowKey = entity.id
            };

            try
            {
                HttpStatusCode code = (await _tableClient.UpsertItemAsync<VisitEntity>(entdb)).StatusCode;
                return (code == HttpStatusCode.OK)
                    ? await RetrieveVisitAsync(entity.id)
                    : null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception thrown");
            }

            return null;
        }

        /// <summary>
        /// Delete a Visit 
        /// </summary>
        /// <param name="id">Visit id to delete</param>
        /// <returns>Visit</returns>        
        public async Task<Visit?> DeleteVisitAsync(string Id)
        {
            try
            {
                var entity = await RetrieveVisitAsync(Id);
                if (entity != null)
                {
                    var response = await _tableClient.DeleteItemAsync<VisitEntity>(Id, new PartitionKey(CosmosStorageVisitService.PartitionKey));
                    if (response != null && ((response.StatusCode == HttpStatusCode.NoContent) || (response.StatusCode == HttpStatusCode.OK)))
                    {
                        return entity;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception thrown");
            }

            return null;
        }

    }
}