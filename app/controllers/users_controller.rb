class UsersController < ApplicationController
  before_action :logged_in_user, only: [:show]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)  
    if @user.save
      log_in @user
      redirect_to documents_path
    else
      render :new
    end
  end

  def show
    @user = User.find(params[:id])
    @my_templates_unreleased=@user.templates.where(scope: 0)
    @my_templates_released=@user.templates.where(scope: 1).order('likes_count DESC')
  end
  
  def edit
      @user=User.find(params[:id])
      @submit='更新'
  end
  
  def update
      @user=User.find(params[:id])
      @my_templates_unreleased=@user.templates.where(scope: 0)
      @my_templates_released=@user.templates.where(scope: 1).order('likes_count DESC')
      if @user.update_attributes(user_params)
          render 'show'
      else
          render 'edit'
      end
  end
  
  def destroy
      @user=User.find(params[:id])
      @user.templates.update_all(:user_id => 3)
      @user.documents.destroy_all
      if User.find(params[:id]).destroy
          redirect_to('/')
      else
          render 'show'
      end
  end

  private 

    def user_params
        params.require(:user).permit(:name, :email, :password,
                                     :password_confirmation,:picture,:bio,:link1,:link2,:link3)
    end

     # beforeアクション

    # ログイン済みユーザーかどうか確認
    def logged_in_user
      unless logged_in?
        flash[:danger] = "ログインしてください"
        redirect_to login_url
      end
    end

    # 正しいユーザーかどうか確認
    def correct_user
      @user = User.find(params[:id])
      redirect_to('/') unless current_user?(@user)
    end

end
