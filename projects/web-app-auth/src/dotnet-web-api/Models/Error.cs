namespace dotnet_web_api.Models
{
    public enum ErrorCode
    {
        NoError = 0,
        Exception,

    }
    /// <summary>
    /// Error Class 
    /// This class is used to describe Error 
    ///
    /// code: error code (0 if no error).  
    /// message: error message if an error occured.  
    /// source: error source if an error occured.  
    /// creationDate: error date if an error occured.  
    /// </summary>          
    public class Error
    {
        public Error()
        {
            this.code = (int)ErrorCode.NoError;
            this.message = "";
            this.source = "";
            this.creationDate = DateTime.MaxValue;
        }
        public Error(int code, string? message, string? source, DateTime creationDate)
        {
            this.code = code;
            this.message = message;
            this.source = source;
            this.creationDate = creationDate;
        }

        public int code { get; set; }
        public string? message { get; set; }
        public string? source { get; set; }
        public DateTime creationDate { get; set; }
    }
}