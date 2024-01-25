namespace dotnet_web_api.Options
{
    /// <summary>
    /// Table client storage options
    /// </summary>
    /// <typeparam name="T">Unique type identifier</typeparam>
    public class TableStorageOptions<T> where T : class
    {
        /// <summary>
        /// Gets or sets the endpoint of the TableClient
        /// </summary>
        public string? Endpoint { get; set; }

        /// <summary>
        /// Gets or sets the table name of the TableClient
        /// </summary>
        public string? TableName { get; set; }
    }
}
