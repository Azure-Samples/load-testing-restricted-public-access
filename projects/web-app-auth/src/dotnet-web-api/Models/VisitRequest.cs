namespace dotnet_web_api.Models
{
    /// <summary>
    /// VisitRequest Class 
    /// Used when calling visit API to create/update an new Visit (POST/PUT Method)
    ///
    /// user: visit user
    /// information: visit information
    /// </summary>    

    public class VisitRequest
    {
        public string user { get; set; } = default!;

        public string information { get; set; } = default!;
    }
}