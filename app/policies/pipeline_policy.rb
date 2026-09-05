class PipelinePolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    account_user.present? && record.account_id == account.id
  end

  def update?
    show?
  end
end
