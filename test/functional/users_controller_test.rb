require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  setup do
    @user = users(:administrator)
  end

  test 'should get index' do
    UserSession.create(@user)
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
    assert_select '#error_body', false
    assert_template 'users/index'
  end

  test 'should get new' do
    UserSession.create(@user)
    get :new
    assert_response :success
    assert_not_nil assigns(:user)
    assert_select '#error_body', false
    assert_template 'users/new'
  end

  test 'should create user' do
    UserSession.create(@user)
    assert_difference('User.count') do
      post :create, :user => {
        :name => 'New name',
        :last_name => 'New last name',
        :email => 'new_user@printhub.com',
        :language => LANGUAGES.first.to_s,
        :username => 'new_user',
        :password => 'new_password',
        :password_confirmation => 'new_password',
        :admin => '1',
        :enable => '1'
      }
    end

    assert_redirected_to users_path
  end

  test 'should show user' do
    UserSession.create(@user)
    get :show, :id => @user.to_param
    assert_response :success
    assert_not_nil assigns(:user)
    assert_select '#error_body', false
    assert_template 'users/show'
  end

  test 'should get edit' do
    UserSession.create(@user)
    get :edit, :id => @user.to_param
    assert_response :success
    assert_not_nil assigns(:user)
    assert_select '#error_body', false
    assert_template 'users/edit'
  end

  test 'should update user' do
    UserSession.create(@user)
    put :update, :id => @user.to_param, :user => {
      :name => 'Updated name',
      :last_name => 'Updated last name',
      :email => 'updated_user@printhub.com',
      :language => LANGUAGES.first.to_s,
      :password => 'updated_password',
      :password_confirmation => 'updated_password',
      :admin => '1',
      :enable => '1'
    }
    assert_redirected_to users_path
    assert_equal 'Updated name', @user.reload.name
  end

  test 'should destroy user' do
    UserSession.create(@user)
    assert_difference('User.count', -1) do
      delete :destroy, :id => @user.to_param
    end

    assert_redirected_to users_path
  end
end