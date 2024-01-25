using Azure.Data.Tables;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Interface definition for a TableClient factory
    /// </summary>
    public interface ITableClientFactory
    {
        /// <summary>
        /// Get a client instance by name
        /// </summary>
        /// <param name="name">Get instance with this id</param>
        /// <returns></returns>
        TableClient? CreateClient(string name);
    }
}
