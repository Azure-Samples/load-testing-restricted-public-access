namespace dotnet_web_api.Options
{
    /// <summary>
    /// Table client storage options
    /// </summary>
    /// <typeparam name="T">Unique type identifier</typeparam>
    public class CosmosDBOptions
    {
        /// <summary>
        /// Gets the subscription Id where Cosmos DB Account is deployed
        /// </summary>
        public string? CosmosDBSubscriptionId { get; set; }

        /// <summary>
        /// Gets the resource group name where Cosmos DB Account is deployed
        /// </summary>
        public string? CosmosDBResourceGroupName { get; set; }

        /// <summary>
        /// Gets the cosmos db account name 
        /// </summary>
        public string? CosmosDBAccountName { get; set; }

        /// <summary>
        /// Gets database name 
        /// </summary>
        public string? CosmosDBDatabaseName { get; set; }

    }
}
