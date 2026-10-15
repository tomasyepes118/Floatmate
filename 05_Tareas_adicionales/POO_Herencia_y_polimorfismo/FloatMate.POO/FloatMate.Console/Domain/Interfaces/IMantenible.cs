namespace FloatMate.Domain.Interfaces;

public interface IMantenible
{
    bool RequiereMantenimiento();

    decimal KilometrosRestantesParaMantenimiento();

    void CompletarMantenimiento(decimal nuevoIntervaloKm);
}
