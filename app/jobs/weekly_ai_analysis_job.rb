class WeeklyAiAnalysisJob < ApplicationJob
  queue_as :default

  def perform
    TrainingPlan.active.find_each do |plan|
      current_week = plan.current_week
      
      next if current_week <= 1
      
      previous_week_workouts = plan.workouts_for_week(current_week - 1)
      completed_count = previous_week_workouts.count(&:completed?)
      
      if completed_count >= 2
        begin
          AiAdjustmentService.new(plan.user, plan).analyze_and_adjust
          Rails.logger.info "AI Analysis completed for user #{plan.user.id}"
        rescue => e
          Rails.logger.error "AI Analysis failed for user #{plan.user.id}: #{e.message}"
        end
      end
    end
  end
end