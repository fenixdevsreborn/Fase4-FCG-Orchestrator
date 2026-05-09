namespace Shared.Contracts.Events;

/// <summary>
/// Evento publicado pelo UsersAPI quando um novo usuário é criado.
/// Consumido pelo NotificationsAPI para enviar e-mail de boas-vindas.
/// </summary>
public record UserCreatedIntegrationEvent
{
    public Guid UserId { get; init; }
    
    public string Email { get; init; } = string.Empty;
    
    public DateTime OccurredAt { get; init; }

    public UserCreatedIntegrationEvent() { }

    public UserCreatedIntegrationEvent(Guid userId, string email, DateTime occurredAt)
    {
        UserId = userId;
        Email = email;
        OccurredAt = occurredAt;
    }
}
