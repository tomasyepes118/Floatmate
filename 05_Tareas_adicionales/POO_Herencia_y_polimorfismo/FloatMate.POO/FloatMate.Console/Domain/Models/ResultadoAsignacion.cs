namespace FloatMate.Domain.Models;

public sealed record ResultadoAsignacion(
    string CodigoVehiculo,
    string TipoVehiculo,
    bool Aprobada,
    string Motivo,
    decimal ConsumoAcpmEstimado);
