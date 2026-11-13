export default function Campo({ nombre, etiqueta, errores = {}, children }) {
  return <div className="form-field"><label htmlFor={nombre} className="form-label">{etiqueta}</label>{children}{errores[nombre] && <small id={`${nombre}-error`} className="field-error">{errores[nombre][0]}</small>}</div>;
}
