using dotnet_web_api.Models;

namespace dotnet_web_api.Services
{
    /// <summary>
    /// Interface definition for Table Storage Visit Service 
    /// </summary>    
    public interface ITableStorageVisitService
    {

        /// <summary>
        /// Get list of all Visits
        /// </summary>
        /// <returns>List<Visit></returns>        
        Task<List<Visit>?> RetrieveAllVisitAsync();

        /// <summary>
        /// Get a Visit by id
        /// </summary>
        /// <param name="id">Visit id to retrieve</param>
        /// <returns>Visit</returns>        
        Task<Visit?> RetrieveVisitAsync(string id);

        /// <summary>
        /// Create a new Visit 
        /// </summary>
        /// <param name="entity">new Visit</param>
        /// <returns>Visit</returns>        
        Task<Visit?> InsertVisitAsync(Visit entity);

        /// <summary>
        /// Update a Visit 
        /// </summary>
        /// <param name="entity">updated Visit</param>
        /// <returns>Visit</returns>        
        Task<Visit?> UpdateVisitAsync(Visit entity);

        /// <summary>
        /// Delete a Visit 
        /// </summary>
        /// <param name="id">Visit id to delete</param>
        /// <returns>Visit</returns>        
        Task<Visit?> DeleteVisitAsync(string id);
    }
}