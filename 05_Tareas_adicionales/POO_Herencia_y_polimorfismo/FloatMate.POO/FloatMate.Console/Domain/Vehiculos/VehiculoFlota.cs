using FloatMate.Domain.Enums;
using FloatMate.Domain.Interfaces;
using FloatMate.Domain.Models;

namespace FloatMate.Domain.Vehiculos;

public abstract class VehiculoFlota : IMantenible
{
    protected VehiculoFlota(
        string codigo,
        string placa,
        int capacidadPasajeros,
        decimal kilometraje,
        decimal proximoMantenimientoKm,
        decimal rendimientoKmPorGalon)
    {
        if (string.IsNullOrWhiteSpace(codigo))
        {
            throw new ArgumentException("El código del vehículo es obligatorio.", nameof(codigo));
        }

        if (string.IsNullOrWhiteSpace(placa))
        {
            throw new ArgumentException("La placa del vehículo es obligatoria.", nameof(placa));
        }

        if (capacidadPasajeros <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(capacidadPasajeros), "La capacidad debe ser mayor que cero.");
        }

        if (kilometraje < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(kilometraje), "El kilometraje no puede ser negativo.");
        }

        if (proximoMantenimientoKm <= kilometraje)
        {
            throw new ArgumentOutOfRangeException(
                nameof(proximoMantenimientoKm),
                "El siguiente mantenimiento debe programarse después del kilometraje actual.");
        }

        if (rendimientoKmPorGalon <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(rendimientoKmPorGalon), "El rendimiento debe ser mayor que cero.");
        }

        Codigo = codigo.Trim();
        Placa = placa.Trim().ToUpperInvariant();
        CapacidadPasajeros = capacidadPasajeros;
        Kilometraje = kilometraje;
        ProximoMantenimientoKm = proximoMantenimientoKm;
        RendimientoKmPorGalon = rendimientoKmPorGalon;
        Estado = EstadoVehiculo.Disponible;
    }

    public string Codigo { get; }

    public string Placa { get; }

    public int CapacidadPasajeros { get; }

    public decimal Kilometraje { get; private set; }

    public decimal ProximoMantenimientoKm { get; private set; }

    public EstadoVehiculo Estado { get; private set; }

    public abstract string TipoVehiculo { get; }

    protected decimal RendimientoKmPorGalon { get; }

    public abstract decimal CalcularConsumoAcpm(Ruta ruta);

    public virtual ResultadoAsignacion EvaluarAsignacion(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);

        if (Estado != EstadoVehiculo.Disponible)
        {
            return CrearRechazo($"El vehículo se encuentra en estado {Estado}.");
        }

        if (RequiereMantenimiento())
        {
            return CrearRechazo("El vehículo debe completar mantenimiento antes de salir.");
        }

        if (ruta.PasajerosEsperados > CapacidadPasajeros)
        {
            return CrearRechazo(
                $"La ruta requiere {ruta.PasajerosEsperados} puestos y el vehículo tiene {CapacidadPasajeros}.");
        }

        return new ResultadoAsignacion(
            Codigo,
            TipoVehiculo,
            true,
            "Cumple disponibilidad, mantenimiento y capacidad.",
            CalcularConsumoAcpm(ruta));
    }

    public void CambiarEstado(EstadoVehiculo nuevoEstado)
    {
        Estado = nuevoEstado;
    }

    public void RegistrarRecorrido(decimal distanciaKm)
    {
        if (distanciaKm <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(distanciaKm), "La distancia debe ser mayor que cero.");
        }

        Kilometraje += distanciaKm;
        Estado = EstadoVehiculo.Disponible;
    }

    public bool RequiereMantenimiento()
    {
        return Kilometraje >= ProximoMantenimientoKm;
    }

    public decimal KilometrosRestantesParaMantenimiento()
    {
        return Math.Max(0, ProximoMantenimientoKm - Kilometraje);
    }

    public void CompletarMantenimiento(decimal nuevoIntervaloKm)
    {
        if (nuevoIntervaloKm <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(nuevoIntervaloKm), "El intervalo debe ser mayor que cero.");
        }

        ProximoMantenimientoKm = Kilometraje + nuevoIntervaloKm;
        Estado = EstadoVehiculo.Disponible;
    }

    protected ResultadoAsignacion CrearRechazo(string motivo)
    {
        return new ResultadoAsignacion(Codigo, TipoVehiculo, false, motivo, 0);
    }

    protected decimal ConsumoBase(decimal distanciaKm)
    {
        return distanciaKm / RendimientoKmPorGalon;
    }
}
