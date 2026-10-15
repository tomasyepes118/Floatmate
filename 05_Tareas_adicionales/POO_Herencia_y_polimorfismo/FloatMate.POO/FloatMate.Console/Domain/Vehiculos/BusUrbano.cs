using FloatMate.Domain.Enums;
using FloatMate.Domain.Models;

namespace FloatMate.Domain.Vehiculos;

public sealed class BusUrbano : VehiculoFlota
{
    private const decimal IncrementoPorParada = 0.003m;

    public BusUrbano(
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

    public override string TipoVehiculo => "Bus urbano";

    public override decimal CalcularConsumoAcpm(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);
        decimal factorParadas = 1 + (ruta.ParadasProgramadas * IncrementoPorParada);
        return decimal.Round(ConsumoBase(ruta.DistanciaKm) * factorParadas, 2);
    }

    public override ResultadoAsignacion EvaluarAsignacion(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);
        ResultadoAsignacion resultadoBase = base.EvaluarAsignacion(ruta);

        if (!resultadoBase.Aprobada)
        {
            return resultadoBase;
        }

        if (ruta.Tipo != TipoRuta.Urbana)
        {
            return CrearRechazo("El bus urbano se asigna únicamente a rutas urbanas.");
        }

        return resultadoBase;
    }
}
