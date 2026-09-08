module Admin
  class UsersController < BaseController
    before_action :set_user, except: :index

    def index
      @query = params[:q].to_s.strip
      @users = filtered_users

      @activity_counts = Activity.group(:user_id).count
      @active_plan_user_ids = TrainingPlan.active.pluck(:user_id).to_set
      @strava_user_ids = StravaIntegration.pluck(:user_id).to_set
    end

    def show
      # Presenca dos campos, nunca o valor -- ver docs/privacy.md.
      @onboarding = {
        "Peso" => @user.weight.present?,
        "Altura" => @user.height.present?,
        "Data de nascimento" => @user.birth_date.present?,
        "Objetivo" => @user.goal.present?,
        "Experiência" => @user.running_experience.present?,
        "Dias preferidos" => @user.preferred_training_days.present?
      }

      @active_plan = @user.active_training_plan
      @plans_count = @user.training_plans.count
      @workout_counts = Workout.joins(:training_plan)
                               .where(training_plans: { user_id: @user.id })
                               .group(:status)
                               .count

      @activities_count = @user.activities.count
      @activity_sources = @user.activities.group(:source).count
      @last_activity = @user.activities.order(start_date: :desc).first

      @strava = @user.strava_integration
      @squad_members = @user.squad_members.includes(:squad)
      @unread_notifications = @user.notifications.unread.count
      @audit_logs = AdminAuditLog.includes(:admin).where(target_user: @user).newest_first.limit(20)
    end

    def disconnect_strava
      integration = @user.strava_integration

      if integration.nil?
        return redirect_to admin_user_path(@user), alert: "Esse usuário não tem Strava conectado."
      end

      athlete_id = integration.strava_athlete_id
      integration.destroy!
      record_audit("strava_disconnect", @user, "athlete #{athlete_id}")

      redirect_to admin_user_path(@user), notice: "Strava desconectado."
    end

    def cancel_training_plan
      plan = @user.active_training_plan

      if plan.nil?
        return redirect_to admin_user_path(@user), alert: "Esse usuário não tem plano ativo."
      end

      plan.update!(status: "cancelled")
      record_audit("plan_cancel", @user, "plano ##{plan.id}")

      redirect_to admin_user_path(@user), notice: "Plano cancelado. O usuário pode gerar um novo."
    end

    def send_password_reset
      @user.send_reset_password_instructions
      record_audit("password_reset_sent", @user)

      redirect_to admin_user_path(@user), notice: "E-mail de redefinição de senha enviado."
    rescue StandardError => e
      Rails.logger.error("[admin] falha ao enviar redefinição de senha para user #{@user.id}: #{e.class}: #{e.message}")
      redirect_to admin_user_path(@user), alert: "Não foi possível enviar o e-mail: #{e.message}"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def filtered_users
      scope = User.order(created_at: :desc)
      return scope if @query.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
      scope.where("LOWER(email) LIKE :pattern OR LOWER(username) LIKE :pattern", pattern: pattern)
    end
  end
end
