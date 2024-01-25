using Azure.Data.Tables;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Factory class to create named TableClient instances
    /// </summary>
    internal class TableClientFactory : ITableClientFactory
    {
        private readonly IDictionary<string, TableClient> _tableClients =
            new Dictionary<string, TableClient>();

        /// <summary>
        /// Add a new TableClient instance
        /// </summary>
        /// <param name="name">Instance id</param>
        /// <param name="instance">TableClient Instance</param>
        /// <exception cref="ArgumentNullException"></exception>
        internal void AddClient(string name, TableClient instance)
        {
            _ = instance ?? throw new ArgumentNullException(nameof(instance));
            if (name == null || string.IsNullOrEmpty(name))
                throw new ArgumentNullException(nameof(name));

            _tableClients[name] = instance;
        }

        /// <summary>
        /// Get a client instance by name
        /// </summary>
        /// <param name="name">Get instance with this id</param>
        /// <returns></returns>
        public TableClient? CreateClient(string name)
        {
            return (name == null || string.IsNullOrEmpty(name)) ? null : _tableClients[name];
        }
    }
}
