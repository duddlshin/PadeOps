module half_channel_concurrent_parameters

      ! TAKE CARE OF TIME NON-DIMENSIONALIZATION IN THIS MODULE

    use exits, only: message
    use kind_parameters,  only: rkind
    use constants, only: zero, kappa, pi 
    implicit none
    integer :: seedu = 321341
    integer :: seedv = 423424
    integer :: seedw = 131344
    real(rkind) :: randomScaleFact = 0.002_rkind ! 0.2% of the mean value
    integer :: nxg, nyg, nzg
    
    real(rkind), parameter :: xdim = 1000._rkind, udim =0.45_rkind
    real(rkind), parameter :: timeDim = xdim/udim

end module     


subroutine initfields_wallM(decompC, decompE, inputfile, mesh, fieldsC, fieldsE)
    use half_channel_concurrent_parameters
    use kind_parameters,    only: rkind
    use constants,          only: zero, one, two, pi, half
    use gridtools,          only: alloc_buffs
    use random,             only: gaussian_random
    use decomp_2d
    use reductions,         only: p_maxval
    implicit none
    type(decomp_info),               intent(in)    :: decompC
    type(decomp_info),               intent(in)    :: decompE
    character(len=*),                intent(in)    :: inputfile
    real(rkind), dimension(:,:,:,:), intent(in), target    :: mesh
    real(rkind), dimension(:,:,:,:), intent(inout), target :: fieldsC
    real(rkind), dimension(:,:,:,:), intent(inout), target :: fieldsE
    integer :: ioUnit
    real(rkind), dimension(:,:,:), pointer :: u, v, w, wC, x, y, z
    real(rkind) :: z0init = 0.1d0, epsnd = 0.02
    real(rkind), dimension(:,:,:), allocatable :: randArr, ybuffC, ybuffE, zbuffC, zbuffE
    integer :: nz, nzE
    real(rkind) :: Xperiods = 3.d0, Yperiods = 3.d0!, Zperiods = 1.d0
    real(rkind) :: zpeak = 0.2d0, noiseAmp = 1.d-2
    real(rkind)  :: Lx = one, Ly = one, Lz = one
    logical :: initPurturbations = .true.
    logical :: z0init_field   ! EYS
    real(rkind) :: z02init, z02init_startx, z02init_endx, zd   ! EYS
    real(rkind) :: idxPlanArea, z0roof    ! EYS
    logical :: CES_LES_int_var = .FALSE.
    integer :: p
    character(8) :: date
    character(10) :: time
    character(5) :: zone
    integer,dimension(8) :: values
    real :: mp
    character(len=20) :: str

    namelist /PBLINPUT/ Lx, Ly, Lz, z0init_field, z0init, z02init, z02init_startx, z02init_endx, initPurturbations, zd, CES_LES_int_var, idxPlanArea, z0roof        ! EYS


    ioUnit = 11
    open(unit=ioUnit, file=trim(inputfile), form='FORMATTED')
    read(unit=ioUnit, NML=PBLINPUT)
    close(ioUnit)


    u  => fieldsC(:,:,:,1)
    v  => fieldsC(:,:,:,2)
    wC => fieldsC(:,:,:,3)
    w  => fieldsE(:,:,:,1)

    z => mesh(:,:,:,3)
    y => mesh(:,:,:,2)
    x => mesh(:,:,:,1)

    epsnd = 5.d0


    if (initPurturbations) then
      u = (one/kappa)*log(z/z0init) + epsnd*cos(Yperiods*two*pi*y/Ly)*exp(-half*(z/zpeak/Lz)**2)
      v = epsnd*(z/Lz)*cos(Xperiods*two*pi*x/Lx)*exp(-half*(z/zpeak/Lz)**2)
    else
      u = (one/kappa)*log(z/z0init)
      v = zero
    end if
    wC= zero

    allocate(randArr(size(wC,1),size(wC,2),size(wC,3)))

    ! EYS code for generating a random seed each time
    if (CES_LES_int_var) then
        call date_and_time(date,time,zone,values)
        read (unit=time,fmt=*) mp
        p = int(1000*mp)
        call message("Adding perturbation")
        write (str, *) p
        call message(str)
        call gaussian_random(randArr,zero,one,p + 100*nrank)
    else
        call gaussian_random(randArr,zero,one,seedu + 100*nrank)
    end if
    
    u  = u + noiseAmp*randArr

    call gaussian_random(randArr,zero,one,seedv + 100*nrank)
    v  = v + noiseAmp*randArr

    deallocate(randArr)

    ! Interpolate wC to w
    allocate(ybuffC(decompC%ysz(1),decompC%ysz(2), decompC%ysz(3)))
    allocate(ybuffE(decompE%ysz(1),decompE%ysz(2), decompE%ysz(3)))

    allocate(zbuffC(decompC%zsz(1),decompC%zsz(2), decompC%zsz(3)))
    allocate(zbuffE(decompE%zsz(1),decompE%zsz(2), decompE%zsz(3)))

    nz = decompC%zsz(3)
    nzE = nz + 1

    call transpose_x_to_y(wC,ybuffC,decompC)
    call transpose_y_to_z(ybuffC,zbuffC,decompC)
    zbuffE = zero
    zbuffE(:,:,2:nzE-1) = half*(zbuffC(:,:,1:nz-1) + zbuffC(:,:,2:nz))
    call transpose_z_to_y(zbuffE,ybuffE,decompE)
    call transpose_y_to_x(ybuffE,w,decompE)


    deallocate(ybuffC,ybuffE,zbuffC, zbuffE)


    nullify(u,v,w,x,y,z)


    call message(0,"Velocity Field Initialized")

end subroutine


subroutine setInhomogeneousNeumannBC_Temp(inputfile, wTh_surf)
    use kind_parameters,    only: rkind
    use constants, only: one, zero
    implicit none

    character(len=*),                intent(in)    :: inputfile
    real(rkind), intent(out) :: wTh_surf
    integer :: iounit, directionID
    namelist /ScalarSourceTestingINPUT/ directionID

    ioUnit = 11
    open(unit=ioUnit, file=trim(inputfile), form='FORMATTED')
    read(unit=ioUnit, NML=ScalarSourceTestingINPUT)
    close(ioUnit)

    ! Do nothing really since this is an unstratified simulation
end subroutine


subroutine setDirichletBC_Temp(inputfile, Tsurf, dTsurf_dt)
    use kind_parameters,    only: rkind
    use constants,          only: zero, one
    implicit none

    character(len=*),                intent(in)    :: inputfile
    real(rkind), intent(out) :: Tsurf, dTsurf_dt
    real(rkind) :: ThetaRef, Lx, Ly, Lz, z0init
    integer :: iounit
    logical :: initPurturbations = .false.
    logical :: z0init_field   ! EYS
    real(rkind) :: z02init, z02init_startx, z02init_endx, zd   ! EYS
    logical :: CES_LES_int_var = .FALSE.
    real(rkind) :: idxPlanArea, z0roof        ! EYS 02012025
    namelist /PBLINPUT/ Lx, Ly, Lz, z0init_field, z0init, z02init, z02init_startx, z02init_endx, initPurturbations, zd, CES_LES_int_var, idxPlanArea, z0roof        ! EYS

    Tsurf = zero; dTsurf_dt = zero; ThetaRef = one

    ioUnit = 11
    open(unit=ioUnit, file=trim(inputfile), form='FORMATTED')
    read(unit=ioUnit, NML=PBLINPUT)
    close(ioUnit)

    ! Do nothing really since this is an unstratified simulation
end subroutine


subroutine set_planes_io(xplanes, yplanes, zplanes)
    implicit none
    integer, dimension(:), allocatable,  intent(inout) :: xplanes
    integer, dimension(:), allocatable,  intent(inout) :: yplanes
    integer, dimension(:), allocatable,  intent(inout) :: zplanes
    integer, parameter :: nxplanes = 1, nyplanes = 1, nzplanes = 2

    allocate(xplanes(nxplanes), yplanes(nyplanes), zplanes(nzplanes))

    xplanes = [10]
    yplanes = [10]
    zplanes = [10,10]

end subroutine

subroutine hook_probes(inputfile, probe_locs)
    use kind_parameters,    only: rkind
    real(rkind), dimension(:,:), allocatable, intent(inout) :: probe_locs
    character(len=*),                intent(in)    :: inputfile
    integer, parameter :: nprobes = 2
    
    ! IMPORTANT : Convention is to allocate probe_locs(3,nprobes)
    ! Example: If you have at least 3 probes:
    ! probe_locs(1,3) : x -location of the third probe
    ! probe_locs(2,3) : y -location of the third probe
    ! probe_locs(3,3) : z -location of the third probe


    ! Add probes here if needed
    ! Example code: The following allocates 2 probes at (0.1,0.1,0.1) and
    ! (0.2,0.2,0.2)  
    allocate(probe_locs(3,nprobes))
    probe_locs(1,1) = 0.1d0; probe_locs(2,1) = 0.1d0; probe_locs(3,1) = 0.1d0;
    probe_locs(1,2) = 0.2d0; probe_locs(2,2) = 0.2d0; probe_locs(3,2) = 0.2d0;

end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!! THE SUBROUTINES UNDER THIS DON'T TYPICALLY NEED TO BE CHANGED !!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!



subroutine meshgen_wallM(decomp, dx, dy, dz, mesh, inputfile)
    use half_channel_concurrent_parameters
    use kind_parameters,  only: rkind
    use constants,        only: one,two
    use decomp_2d,        only: decomp_info
    implicit none

    type(decomp_info),           intent(in)    ::decomp
    real(rkind),                 intent(inout) ::dx,dy,dz
    real(rkind), dimension(:,:,:,:), intent(inout) :: mesh
    integer :: i,j,k, ioUnit
    character(len=*),                intent(in)    :: inputfile
    integer :: ix1, ixn, iy1, iyn, iz1, izn
    real(rkind)  :: Lx = one, Ly = one, Lz = one
    logical :: initPurturbations = .false.
    real(rkind) :: z0init = 0.1d0 
    logical :: z0init_field   ! EYS
    real(rkind) :: z02init, z02init_startx, z02init_endx, zd  ! EYS
    logical :: CES_LES_int_var = .FALSE.
    real(rkind) :: idxPlanArea, z0roof        ! EYS 02012025
    namelist /PBLINPUT/ Lx, Ly, Lz, z0init_field, z0init, z02init, z02init_startx, z02init_endx, initPurturbations, zd, CES_LES_int_var, idxPlanArea, z0roof        ! EYS


    ioUnit = 11
    open(unit=ioUnit, file=trim(inputfile), form='FORMATTED')
    read(unit=ioUnit, NML=PBLINPUT)
    close(ioUnit)

    !Lx = two*pi; Ly = two*pi; Lz = one

    nxg = decomp%xsz(1); nyg = decomp%ysz(2); nzg = decomp%zsz(3)

    ! If base decomposition is in Y
    ix1 = decomp%xst(1); iy1 = decomp%xst(2); iz1 = decomp%xst(3)
    ixn = decomp%xen(1); iyn = decomp%xen(2); izn = decomp%xen(3)

    associate( x => mesh(:,:,:,1), y => mesh(:,:,:,2), z => mesh(:,:,:,3) )

        dx = Lx/real(nxg,rkind)
        dy = Ly/real(nyg,rkind)
        dz = Lz/real(nzg,rkind)

        do k=1,size(mesh,3)
            do j=1,size(mesh,2)
                do i=1,size(mesh,1)
                    x(i,j,k) = real( ix1 + i - 1, rkind ) * dx
                    y(i,j,k) = real( iy1 + j - 1, rkind ) * dy
                    z(i,j,k) = real( iz1 + k - 1, rkind ) * dz + dz/two
                end do
            end do
        end do

        ! Shift everything to the origin
        x = x - dx
        y = y - dy
        z = z - dz

    end associate

end subroutine


subroutine set_Reference_Temperature(inputfile, Tref)
    use kind_parameters,    only: rkind
    implicit none
    character(len=*),                intent(in)    :: inputfile
    real(rkind), intent(out) :: Tref
    real(rkind) :: Lx, Ly, Lz, z0init
    integer :: iounit
    logical :: initPurturbations = .false.
    logical :: z0init_field   ! EYS
    real(rkind) :: z02init, z02init_startx, z02init_endx, zd   ! EYS
    logical :: CES_LES_int_var = .FALSE.
    real(rkind) :: idxPlanArea, z0roof        ! EYS 02012025
    namelist /PBLINPUT/ Lx, Ly, Lz, z0init_field, z0init, z02init, z02init_startx, z02init_endx, initPurturbations, zd, CES_LES_int_var, idxPlanArea, z0roof        ! EYS

    ioUnit = 11
    open(unit=ioUnit, file=trim(inputfile), form='FORMATTED')
    read(unit=ioUnit, NML=PBLINPUT)
    close(ioUnit)

    Tref = 0.d0

    ! Do nothing really since this is an unstratified simulation

end subroutine


subroutine set_KS_planes_io(planesCoarseGrid, planesFineGrid)
    integer, dimension(:), allocatable,  intent(inout) :: planesFineGrid
    integer, dimension(:), allocatable,  intent(inout) :: planesCoarseGrid
    
    allocate(planesCoarseGrid(1), planesFineGrid(1))
    planesCoarseGrid = [8]
    planesFineGrid = [16]

end subroutine


subroutine initScalar(decompC, inpDirectory, mesh, scalar_id, scalarField)
    use kind_parameters, only: rkind
    use decomp_2d,        only: decomp_info
    type(decomp_info),                                          intent(in)    :: decompC
    character(len=*),                intent(in)    :: inpDirectory
    real(rkind), dimension(:,:,:,:), intent(in)    :: mesh
    integer, intent(in)                            :: scalar_id
    real(rkind), dimension(:,:,:), intent(out)     :: scalarField

    scalarField = 0.d0
end subroutine 

subroutine setScalar_source(decompC, inpDirectory, mesh, scalar_id, scalarSource)
    use kind_parameters, only: rkind
    use decomp_2d,        only: decomp_info
    type(decomp_info),                                          intent(in)    ::decompC
    character(len=*),                intent(in)    :: inpDirectory
    real(rkind), dimension(:,:,:,:), intent(in)    :: mesh
    integer, intent(in)                            :: scalar_id
    real(rkind), dimension(:,:,:), intent(out)     :: scalarSource

    scalarSource = 0.d0
end subroutine
