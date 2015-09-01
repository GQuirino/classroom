class GroupAssignmentsController < ApplicationController
  include OrganizationAuthorization
  include StarterCode

  before_action :set_group_assignment, except: [:new, :create]
  before_action :set_groupings,        except: [:show]

  decorates_assigned :organization
  decorates_assigned :group_assignment

  rescue_from GitHub::Error, GitHub::Forbidden, GitHub::NotFound, with: :error

  def new
    @group_assignment = GroupAssignment.new
  end

  def create
    @group_assignment = GroupAssignment.new(new_group_assignment_params)

    if @group_assignment.save
      CreateGroupingJob.perform_later(@group_assignment, new_grouping_params)
      CreateGroupAssignmentInvitationJob.perform_later(@group_assignment)

      flash[:success] = "\"#{@group_assignment.title}\" has been created!"
      redirect_to organization_group_assignment_path(@organization, @group_assignment)
    else
      render :new
    end
  end

  def show
    @group_assignment_repos = @group_assignment.group_assignment_repos.page(params[:page])
  end

  def edit
  end

  def update
    if @group_assignment.update_attributes(update_group_assignment_params)
      flash[:success] = "Assignment \"#{@group_assignment.title}\" updated"
      redirect_to organization_group_assignment_path(@organization, @group_assignment)
    else
      render :edit
    end
  end

  def destroy
    if @group_assignment.update_attributes(deleted_at: Time.zone.now)
      DestroyResourceJob.perform_later(@group_assignment)
      flash[:success] = "A job has been queued to delete your group assignment \"#{@group_assignment.title}\""
      redirect_to @organization
    else
      render :edit
    end
  end

  private

  def error(exception)
    flash[:error] = exception.message
    redirect_to :back
  end

  def new_group_assignment_params
    params
      .require(:group_assignment)
      .permit(:title, :public_repo, :grouping_id)
      .merge(creator: current_user,
             organization: @organization,
             starter_code_repo_id: starter_code_repository_id(params[:repo_name]))
  end

  def new_grouping_params
    params
      .require(:grouping)
      .permit(:title)
      .merge(organization: @organization)
  end

  def set_groupings
    @groupings = @organization.groupings.map { |group| [group.title, group.id] }
  end

  def set_group_assignment
    @group_assignment = GroupAssignment.friendly.find(params[:id])
  end

  def update_group_assignment_params
    params
      .require(:group_assignment)
      .permit(:title, :public_repo)
      .merge(starter_code_repo_id: starter_code_repository_id(params[:repo_name]))
  end
end