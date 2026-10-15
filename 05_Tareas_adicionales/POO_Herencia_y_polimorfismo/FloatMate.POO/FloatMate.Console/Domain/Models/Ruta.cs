using FloatMate.Domain.Enums;

namespace FloatMate.Domain.Models;

public sealed class Ruta
{
    public Ruta(
        string nombre,
        TipoRuta tipo,
        decimal distanciaKm,
        int pasajerosEsperados,
        int paradasProgramadas)
    {
        if (string.IsNullOrWhiteSpace(nombre))
        {
            throw new ArgumentException("El nombre de la ruta es obligatorio.", nameof(nombre));
        }

        if (distanciaKm <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(distanciaKm), "La distancia debe ser mayor que cero.");
        }

        if (pasajerosEsperados < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(pasajerosEsperados), "La cantidad de pasajeros no puede ser negativa.");
        }

        if (paradasProgramadas < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(paradasProgramadas), "La cantidad de paradas no puede ser negativa.");
        }

        Nombre = nombre.Trim();
        Tipo = tipo;
        DistanciaKm = distanciaKm;
        PasajerosEsperados = pasajerosEsperados;
        ParadasProgramadas = paradasProgramadas;
    }

    public string Nombre { get; }

    public TipoRuta Tipo { get; }

    public decimal DistanciaKm { get; }

    public int PasajerosEsperados { get; }

    public int ParadasProgramadas { get; }
}
