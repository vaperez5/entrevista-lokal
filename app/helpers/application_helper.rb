module ApplicationHelper
  # El dinero se guarda como entero de pesos chilenos: sin decimales ni
  # centavos. Acá solo lo formateamos para mostrarlo.
  def clp(amount)
    "$#{number_with_delimiter(amount, delimiter: '.')}"
  end
end
