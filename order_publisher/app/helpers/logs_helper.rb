module LogsHelper
  def service_icon(name)
    case name
    when 'Email Service'
      'envelope'
    when 'Inventory Service'
      'boxes'
    when 'Analytics Service'
      'chart-bar'
    when 'Order Publisher'
      'shopping-cart'
    else
      'cog'
    end
  end
end 