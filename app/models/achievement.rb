class Achievement < ApplicationRecord
  # badge_type: nunca lida em nenhum lugar do app. Coluna fica no banco ate o
  # deploy com ignored_columns estar no ar; remove_column vem depois.
  self.ignored_columns += %w[badge_type]
end
