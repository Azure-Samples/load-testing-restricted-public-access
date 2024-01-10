using Azure;
using Azure.Data.Tables;
using dotnet_web_api.Models;
using System.Net;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Implementation of Table Storage Visit Service 
    /// </summary>        
    public class TableStorageVisitService : ITableStorageVisitService
    {
        private const string PartitionKey = "visit";

        private readonly TableClient _tableClient;
        private readonly ILogger<TableStorageVisitService> _logger;

        public TableStorageVisitService(ITableClientFactory clientFactory, ILogger<TableStorageVisitService> logger)
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
                var queryResultsFilter = _tableClient.QueryAsync<VisitEntity>(filter: $"PartitionKey eq '{PartitionKey}'");

                var list = new List<Visit>();
                // Iterate the <see cref="Pageable"> to access all queried entities.
                await foreach (VisitEntity ent in queryResultsFilter)
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
                            creationDate = ent.creationDate,
                        };

                        list.Add(entity);
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
                var queryResultsFilter = _tableClient.QueryAsync<VisitEntity>(filter: $"PartitionKey eq '{PartitionKey}' and RowKey eq '{id}'");

                // Iterate the <see cref="Pageable"> to access all queried entities.
                await foreach (VisitEntity ent in queryResultsFilter)
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
                            creationDate = ent.creationDate,
                        };
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
                return (_tableClient.AddEntity(entdb)?.Status == (int)HttpStatusCode.NoContent)
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
                return (_tableClient.UpdateEntity(entdb, ETag.All)?.Status == (int)HttpStatusCode.NoContent)
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
                    var response = await _tableClient.DeleteEntityAsync(PartitionKey, Id);
                    if (response != null && response.Status == (int)HttpStatusCode.NoContent)
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