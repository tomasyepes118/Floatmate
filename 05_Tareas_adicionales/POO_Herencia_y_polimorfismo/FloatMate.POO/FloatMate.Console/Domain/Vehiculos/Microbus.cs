using FloatMate.Domain.Models;

namespace FloatMate.Domain.Vehiculos;

public sealed class Microbus : VehiculoFlota
{
    private const decimal AjusteAltaOcupacion = 0.05m;

    public Microbus(
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

    public override string TipoVehiculo => "Microbús";

    public override decimal CalcularConsumoAcpm(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);
        decimal ocupacion = (decimal)ruta.PasajerosEsperados / CapacidadPasajeros;
        decimal factorCarga = ocupacion >= 0.80m ? 1 + AjusteAltaOcupacion : 1;
        return decimal.Round(ConsumoBase(ruta.DistanciaKm) * factorCarga, 2);
    }
}
