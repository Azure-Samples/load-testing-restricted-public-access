using Azure;
using Azure.Data.Tables;
using Newtonsoft.Json;
namespace dotnet_web_api.Models
{
    /// <summary>
    /// VisitEntity Class 
    /// This class is used to store Visit in Azure Storage Table
    ///
    /// PartitionKey: 'visit'
    /// RowKey: unique visit id (guid)
    /// user: visit user
    /// information: information related to the visit 
    /// </summary>        
    public class VisitEntity : ITableEntity
    {

        public string? PartitionKey { get; set; }
        [JsonProperty(PropertyName = "id")]
        public string? RowKey { get; set; }
        public DateTimeOffset? Timestamp { get; set; }
        public ETag ETag { get; set; }

        public string user { get; set; } = default!;
        public string information { get; set; } = default!;
        public string localIp { get; set; } = "";
        public int localPort { get; set; } = 0;
        public string remoteIp { get; set; } = "";
        public int remotePort { get; set; } = 0;

        public DateTime creationDate { get; set; }
    }
}