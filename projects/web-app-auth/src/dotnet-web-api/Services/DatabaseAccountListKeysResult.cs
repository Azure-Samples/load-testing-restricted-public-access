using Microsoft.Azure.Cosmos;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// class used to retirve the Azure Cosmos DB keys
    /// </summary>
    public class DatabaseAccountListKeysResult
    {
        public string? primaryMasterKey { get; set; }
        public string? primaryReadonlyMasterKey { get; set; }
        public string? secondaryMasterKey { get; set; }
        public string? secondaryReadonlyMasterKey { get; set; }
    }
}
