using FloatMate.Domain.Models;
using FloatMate.Domain.Vehiculos;

namespace FloatMate.Application;

public sealed class GestorFlota
{
    private readonly List<VehiculoFlota> _vehiculos;

    public GestorFlota(IEnumerable<VehiculoFlota> vehiculos)
    {
        ArgumentNullException.ThrowIfNull(vehiculos);
        _vehiculos = vehiculos.ToList();

        if (_vehiculos.Count == 0)
        {
            throw new ArgumentException("La flota debe contener al menos un vehículo.", nameof(vehiculos));
        }
    }

    public IReadOnlyList<VehiculoFlota> Vehiculos => _vehiculos.AsReadOnly();

    public IReadOnlyList<ResultadoAsignacion> EvaluarRuta(Ruta ruta)
    {
        ArgumentNullException.ThrowIfNull(ruta);

        return _vehiculos
            .Select(vehiculo => vehiculo.EvaluarAsignacion(ruta))
            .ToList()
            .AsReadOnly();
    }

    public ResultadoAsignacion? SeleccionarMejorOpcion(Ruta ruta)
    {
        return EvaluarRuta(ruta)
            .Where(resultado => resultado.Aprobada)
            .OrderBy(resultado => resultado.ConsumoAcpmEstimado)
            .FirstOrDefault();
    }
}
