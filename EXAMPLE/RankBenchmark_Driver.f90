!> @file
!> @brief This example generates a random LR product, or reads a full matrix from disk, and compress it using entry-valuation-based APIs
!> @details Note that instead of the use of precision dependent subroutine/module/type names "z_", one can also use the following \n
!> #define DAT 0 \n
!> #include "zButterflyPACK_config.fi" \n
!> which will macro replace precision-independent subroutine/module/type names "X" with "z_X" defined in SRC_DOUBLECOMLEX with double-complex precision

module APPLICATION_MODULE_RankBenchmark
use z_BPACK_DEFS
implicit none

	!**** define your application-related variables here
	type quant_app
		real(kind=8), allocatable :: locations_m(:,:),locations_n(:,:) ! geometrical points
		integer,allocatable:: permutation_m(:),permutation_n(:)
		integer:: rank
		integer:: Nunk_m,Nunk_n
		integer:: Ndim
		integer:: tst=1
		real(kind=8)::wavelen,zdist
	end type quant_app

contains

	!**** user-defined subroutine to sample Z_mn as full matrix
	subroutine Zelem_User(m,n,value,quant)
		use z_BPACK_DEFS
		implicit none

		class(*),pointer :: quant
		integer, INTENT(IN):: m,n
		complex(kind=8)::value
		integer ii

		real(kind=8)::pos_o(100),pos_s(100), dist, waven, dotp, sx,cx,xk,kr, theta,phi,d,f,x,y,tau,p,h,k(3)

		select TYPE(quant)
		type is (quant_app)
			if(quant%tst==4)then
				pos_o(1:quant%Ndim) = quant%locations_m(:,m)
				pos_s(1:quant%Ndim) = quant%locations_n(:,n)
				dotp = dot_product(pos_o(1:quant%Ndim),pos_s(1:quant%Ndim))
				value = EXP(-2*BPACK_pi*BPACK_junit*dotp)
			elseif(quant%tst==5)then
				pos_o(1:quant%Ndim) = quant%locations_m(:,m)
				pos_s(1:quant%Ndim) = quant%locations_n(:,n)
				xk = dot_product(pos_o(1:quant%Ndim),pos_s(1:quant%Ndim))
				sx = (2+sin(2*BPACK_pi*pos_s(1))*sin(2*BPACK_pi*pos_s(2)))/16d0;
				cx = (2+cos(2*BPACK_pi*pos_s(1))*cos(2*BPACK_pi*pos_s(2)))/16d0;
				kr = sqrt(sx**2*pos_o(1)**2 + cx**2*pos_o(2)**2);
				value = EXP(2*BPACK_pi*BPACK_junit*(xk + kr))
			elseif(quant%tst==6)then
				pos_o(1:quant%Ndim) = quant%locations_m(:,m)
				pos_s(1:quant%Ndim) = quant%locations_n(:,n)
				theta = pos_o(1)*BPACK_pi/8d0 ! only constrain theta from 0 to pi/8, otherwise the phase function becomes unbounded
				phi = pos_o(2)*2*BPACK_pi
				d = pos_o(3)
				x = pos_s(1)
				y = pos_s(2)
				f = pos_s(3) * size(quant%locations_n,2)**(1/3d0)
				kr = f*(-tan(theta)*cos(phi)*x - tan(theta)*sin(phi)*y + d/cos(theta))
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			elseif(quant%tst==9)then
				pos_o(1:quant%Ndim) = quant%locations_m(:,m)
				pos_s(1:quant%Ndim) = quant%locations_n(:,n)
				k = pos_s(1:quant%Ndim)
				cx = (3d0+sin(2*BPACK_pi*pos_o(1))*sin(2*BPACK_pi*pos_o(2))*sin(2*BPACK_pi*pos_o(3)))/100d0;
				xk = dot_product(pos_o(1:quant%Ndim),k)
				kr = xk+cx*sqrt(sum((k)**2d0))
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			else
				pos_o(1:quant%Ndim) = quant%locations_m(:,m)
				pos_s(1:quant%Ndim) = quant%locations_n(:,n)
				dist = sqrt(sum((pos_o(1:quant%Ndim)-pos_s(1:quant%Ndim))**2d0))
				waven=2*BPACK_pi/quant%wavelen
				value = EXP(-BPACK_junit*waven*dist)/dist
			endif
		class default
			write(*,*)"unexpected type"
			stop
		end select
	end subroutine Zelem_User


	!**** user-defined subroutine to sample Z_mn as full matrix (note that this is for the BF interface not for the BPACK interface)
	subroutine ZBelem_User(m,n,value_e,quant)
		use z_BPACK_DEFS
		implicit none

		class(*),pointer :: quant
		integer, INTENT(IN):: m,n
		complex(kind=8)::value_e
		integer ii,m1,n1

		if(m>0)then
			m1=m
			n1=-n
		else
			m1=n
			n1=-m
		endif

		!!! m,n still need to convert to the original order, using new2old of mshr and mshc
		select TYPE(quant)
		type is (quant_app)
			m1=quant%permutation_m(m1)
			n1=quant%permutation_n(n1)
		class default
			write(*,*)"unexpected type"
			stop
		end select

		call Zelem_User(m1,n1,value_e,quant)
	end subroutine ZBelem_User


end module APPLICATION_MODULE_RankBenchmark


PROGRAM ButterflyPACK_RankBenchmark
    use z_BPACK_DEFS
    use APPLICATION_MODULE_RankBenchmark
	use z_BPACK_Solve_Mul

	use z_BPACK_structure
	use z_BPACK_factor
	use z_BPACK_constr
#ifdef HAVE_OPENMP
	use omp_lib
#endif
	use z_MISC_Utilities
	use z_BPACK_constr
	use z_BPACK_utilities
    implicit none

    integer rank,ii,jj,kk
	real(kind=8),allocatable:: datain(:)
	real(kind=8) :: wavelen, ds, ppw
	integer :: ierr
	type(z_Hoption),target::option
	type(z_Hstat),target::stats
	type(z_mesh),target::msh,mshr,mshc
	type(z_kernelquant),target::ker
	type(quant_app),target::quant
	type(z_Bmatrix),target::bmat
	integer,allocatable:: groupmembers(:)
	integer nmpi, Nperdim, dim_i, dims(100), inds(100)
	integer level,Maxlevel,m,n
	type(z_proctree),target::ptree
	integer,allocatable::Permutation(:)
	integer Nunk_loc,Nunk_m_loc, Nunk_n_loc
	integer,allocatable::tree(:),tree_m(:),tree_n(:)
	complex(kind=8),allocatable::rhs_glo(:,:),rhs_loc(:,:),x_glo(:,:),x_loc(:,:),xin_loc(:,:),xout_loc(:,:)
	integer nrhs
	type(z_matrixblock) ::blocks
	character(len=1024)  :: strings,strings1
	integer flag,nargs

	!**** nmpi and groupmembers should be provided by the user
	call MPI_Init(ierr)
	call MPI_Comm_size(MPI_Comm_World,nmpi,ierr)
	allocate(groupmembers(nmpi))
	do ii=1,nmpi
		groupmembers(ii)=(ii-1)
	enddo

	!**** create the process tree
	call z_CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree)
	deallocate(groupmembers)
	!**** initialize stats and option
	call z_InitStat(stats)
	call z_SetDefaultOptions(option)


	!**** set solver parameters
	option%ErrSol=1  ! whether or not checking the factorization accuracy
	! option%format=  HODLR! HMAT!   ! the hierarhical format
	option%near_para=0.01d0        ! admissibiltiy condition, not referenced if option%format=  HODLR
	option%verbosity=1             ! verbosity level
	option%LRlevel=0             ! 0: low-rank compression 100: butterfly compression

	! geometry points available
	option%xyzsort=TM ! no reordering will be perfomed
	option%knn=0   ! neareat neighbour points per geometry point, which helps improving the compression accuracy
	quant%Ndim = 3 ! dimension of the geometry information, not referenced if option%nogeo=1


	quant%tst = 2
    quant%wavelen = 0.25d0/8d0
	ppw=2
	quant%zdist = 1

	nargs = iargc()
	ii=1
	do while(ii<=nargs)
		call getarg(ii,strings)
		if(trim(strings)=='-quant')then ! user-defined quantity parameters
			flag=1
			do while(flag==1)
				ii=ii+1
				if(ii<=nargs)then
					call getarg(ii,strings)
					if(strings(1:2)=='--')then
						ii=ii+1
						call getarg(ii,strings1)
						if(trim(strings)=='--tst')then
							read(strings1,*)quant%tst
						elseif(trim(strings)=='--wavelen')then
							read(strings1,*)quant%wavelen
						elseif(trim(strings)=='--ndim_FIO')then
							read(strings1,*)quant%Ndim
						elseif(trim(strings)=='--N_FIO')then
							read(strings1,*)Nperdim
						elseif(trim(strings)=='--ppw')then
							read(strings1,*)ppw
						elseif(trim(strings)=='--zdist')then
							read(strings1,*)quant%zdist
						else
							if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown quant: ', trim(strings)
						endif
					else
						flag=0
					endif
				else
					flag=0
				endif
			enddo
		else if(trim(strings)=='-option')then ! options of ButterflyPACK
			call z_ReadOption(option,ptree,ii)
		else
			if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown argument: ',trim(strings)
			ii=ii+1
		endif
	enddo



!******************************************************************************!
! Read a full non-square matrix and do a BF compression

    ds = quant%wavelen/ppw
    if(quant%tst==1)then ! two colinear plate
      Nperdim = NINT(1d0/ds)
      quant%Nunk_m = Nperdim*Nperdim
      quant%Nunk_n = Nperdim*Nperdim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(2,dims, m, inds)
		ii=inds(1)
		jj=inds(2)
		quant%locations_m(1,m)=ii*ds+1+quant%zdist
		quant%locations_m(2,m)=jj*ds
		quant%locations_m(3,m)=0
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(2,dims, n, inds)
		ii=inds(1)
		jj=inds(2)
		quant%locations_n(1,n)=ii*ds
		quant%locations_n(2,n)=jj*ds
		quant%locations_n(3,n)=0
	  enddo

    elseif(quant%tst==2)then ! two parallel plate

      Nperdim = NINT(1d0/ds)
      quant%Nunk_m = Nperdim*Nperdim
      quant%Nunk_n = Nperdim*Nperdim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(2,dims, m, inds)
		ii=inds(1)
		jj=inds(2)
		quant%locations_m(1,m)=0
		quant%locations_m(2,m)=ii*ds
		quant%locations_m(3,m)=jj*ds
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(2,dims, n, inds)
		ii=inds(1)
		jj=inds(2)
		quant%locations_n(1,n)=quant%zdist
		quant%locations_n(2,n)=ii*ds
		quant%locations_n(3,n)=jj*ds
	  enddo

	elseif(quant%tst==3)then ! two 3D cubes
      Nperdim = NINT(1d0/ds)
      quant%Nunk_m = Nperdim*Nperdim*Nperdim
      quant%Nunk_n = Nperdim*Nperdim*Nperdim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(3,dims, m, inds)
		ii=inds(1)
		jj=inds(2)
		kk=inds(3)
		quant%locations_m(1,m)=ii*ds
		quant%locations_m(2,m)=jj*ds
		quant%locations_m(3,m)=kk*ds
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(3,dims, n, inds)
		ii=inds(1)
		jj=inds(2)
		kk=inds(3)
		quant%locations_n(1,n)=ii*ds+1+quant%zdist
		quant%locations_n(2,n)=jj*ds
		quant%locations_n(3,n)=kk*ds
	  enddo
	elseif(quant%tst==4)then ! DFT
      quant%Nunk_m = Nperdim**quant%Ndim
      quant%Nunk_n = Nperdim**quant%Ndim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, m, inds)
		do dim_i=1,quant%Ndim
			quant%locations_m(dim_i,m)=inds(dim_i)-1
		enddo
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, n, inds)
		do dim_i=1,quant%Ndim
			quant%locations_n(dim_i,n)=dble(inds(dim_i)-1)/Nperdim
		enddo
	  enddo

	elseif(quant%tst==5)then ! 2D Radon transform for elipse integral from "Approximate inversion of discrete Fourier integral operators" and "Fast Computation of Fourier Integral Operators"
	  quant%Ndim = 2
      quant%Nunk_m = Nperdim**quant%Ndim
      quant%Nunk_n = Nperdim**quant%Ndim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, m, inds)
		do dim_i=1,quant%Ndim
			quant%locations_m(dim_i,m)=inds(dim_i)-1-Nperdim/2
		enddo
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, n, inds)
		do dim_i=1,quant%Ndim
			quant%locations_n(dim_i,n)=dble(inds(dim_i)-1)/Nperdim
		enddo
	  enddo
	elseif(quant%tst==6)then ! 3D Radon transform for a plane interal generalized from "A fast butterfly algorithm for generalized Radon transforms"
	  quant%Ndim = 3
      quant%Nunk_m = Nperdim**quant%Ndim
      quant%Nunk_n = Nperdim**quant%Ndim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, m, inds)
		do dim_i=1,quant%Ndim
			quant%locations_m(dim_i,m)=dble(inds(dim_i)-1)/Nperdim+1d0/Nperdim/2d0
		enddo
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, n, inds)
		do dim_i=1,quant%Ndim
			quant%locations_n(dim_i,n)=dble(inds(dim_i)-1)/Nperdim
		enddo
	  enddo
	elseif(quant%tst==9)then ! 3D Radon transform for sphere integral from "A Fast Butterfly Algorithm for the Computation of Fourier Integral Operators"
	  quant%Ndim = 3

      quant%Nunk_m = Nperdim**quant%Ndim
      quant%Nunk_n = Nperdim**quant%Ndim
	  allocate(quant%locations_m(quant%Ndim,quant%Nunk_m))
	  allocate(quant%locations_n(quant%Ndim,quant%Nunk_n))
	  dims = Nperdim
	  do m=1,quant%Nunk_m
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, m, inds)
		do dim_i=1,quant%Ndim
			quant%locations_m(dim_i,m)= dble(inds(dim_i)-1)/Nperdim
		enddo
	  enddo
	  do n=1,quant%Nunk_n
		call z_SingleIndexToMultiIndex(quant%Ndim,dims, n, inds)
		do dim_i=1,quant%Ndim
			quant%locations_n(dim_i,n)=dble(inds(dim_i)-1)-Nperdim/2
		enddo
	  enddo
	endif



	call z_PrintOptions(option,ptree)


	if(ptree%MyID==Main_ID)then
	write (*,*) ''
	write (*,*) 'RankBenchmark computing'
	write (*,*) 'Matrix size:', quant%Nunk_m, quant%Nunk_n
	write (*,*) ''
	endif
	!***********************************************************************

	!**** register the user-defined function and type in ker
	ker%QuantApp => quant
	ker%FuncZmn => ZBelem_User

	allocate(quant%Permutation_m(quant%Nunk_m))
	allocate(quant%Permutation_n(quant%Nunk_n))
	call z_BF_Construct_Init(quant%Nunk_m, quant%Nunk_n, Nunk_m_loc, Nunk_n_loc, quant%Permutation_m, quant%Permutation_n, blocks, option, stats, msh, ker, ptree, Coordinates_m=quant%locations_m,Coordinates_n=quant%locations_n)
	call MPI_Bcast(quant%Permutation_m,quant%Nunk_m,MPI_integer,0,ptree%comm,ierr)
	call MPI_Bcast(quant%Permutation_n,quant%Nunk_n,MPI_integer,0,ptree%comm,ierr)

	call z_BF_Construct_Element_Compute(blocks, option, stats, msh, ker, ptree)
	nrhs=1
	allocate(xin_loc(Nunk_n_loc,nrhs))
	xin_loc=1
	allocate(xout_loc(Nunk_m_loc,nrhs))
	call z_BF_Mult('N', xin_loc, xout_loc, Nunk_n_loc, Nunk_m_loc, nrhs, blocks, option, stats, ptree)
	deallocate(xin_loc)
	deallocate(xout_loc)
!******************************************************************************!

	!**** print statistics
	call z_PrintStat(stats,ptree)

	call z_delete_proctree(ptree)
	call z_delete_Hstat(stats)
	call z_delete_mesh(msh)
	call z_delete_kernelquant(ker)
	call z_BPACK_delete(bmat)


    if(ptree%MyID==Main_ID .and. option%verbosity>=0)write(*,*) "-------------------------------program end-------------------------------------"

	call z_blacs_exit_wrp(1)
	call MPI_Finalize(ierr)

end PROGRAM ButterflyPACK_RankBenchmark



