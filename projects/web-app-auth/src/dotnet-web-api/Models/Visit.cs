namespace dotnet_web_api.Models
{
    /// <summary>
    /// Visit Class 
    /// Returned when calling visit API
    ///
    /// id: unique visit id (guid)
    /// user: visit user
    /// information: information related to the visit in Azure Storage
    /// date: visit creation date.  
    /// </summary>    
    public class Visit
    {
        public string id { get; set; } = default!;
        public string user { get; set; } = default!;
        public string information { get; set; } = default!;
        public string localIp { get; set; } = "";
        public int localPort { get; set; } = 0;
        public string remoteIp { get; set; } = "";
        public int remotePort { get; set; } = 0;
        public DateTime creationDate { get; set; }
    }
}