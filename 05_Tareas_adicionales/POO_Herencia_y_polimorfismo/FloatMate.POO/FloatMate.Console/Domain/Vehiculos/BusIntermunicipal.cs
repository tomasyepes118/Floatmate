using FloatMate.Domain.Models;

namespace FloatMate.Domain.Vehiculos;

public sealed class BusIntermunicipal : VehiculoFlota
{
    private const decimal ReservaOperativa = 0.08m;

    public BusIntermunicipal(
        string codigo,
        string placa,
        int capacidadPasajeros,
        decimal kilometraje,
        decimal proximoMantenimientoKm,
        decimal rendimientoKmPorGalon)
        : base(
            codigo,
            placa,
            capacidadPasajeros,
            kilometraje,
            proximoMantenimientoKm,
            rendimientoKmPorGalon)
    {
    }

    public override string TipoVehiculo => "Bus intermunicipal";

    public override decimal CalcularConsumoAcpm(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);
        return decimal.Round(ConsumoBase(ruta.DistanciaKm) * (1 + ReservaOperativa), 2);
    }
}
